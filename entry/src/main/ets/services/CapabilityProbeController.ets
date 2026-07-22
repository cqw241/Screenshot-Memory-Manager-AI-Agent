import {
  abilityAccessCtrl,
  common,
  Permissions,
  Want,
  wantAgent
} from '@kit.AbilityKit';
import { dataSharePredicates } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { notificationManager } from '@kit.NotificationKit';
import {
  extractProbeCardId,
  ProbeEvidenceEvent,
  ProbeEvidenceInput,
  ProbeEventKind,
  ProbeWantParameters
} from '../models/CapabilityProbeModels';
import { CapabilityProbeRepository } from './CapabilityProbeRepository';

const READ_IMAGEVIDEO: Permissions = 'ohos.permission.READ_IMAGEVIDEO';
const PROBE_NOTIFICATION_ID: number = 30001;
const PROBE_CARD_ID: string = 'probe-card-s03-001';
const MAX_LATEST_ASSETS: number = 12;

export enum ProbeMediaTrialKind {
  SCREENSHOT = 'SCREENSHOT',
  CAMERA = 'CAMERA',
  DOWNLOAD = 'DOWNLOAD',
  SAVED_IMAGE = 'SAVED_IMAGE'
}

export class CapabilityProbeController {
  private readonly context: common.UIAbilityContext;
  private readonly repository: CapabilityProbeRepository;
  private readonly mediaHelper: photoAccessHelper.PhotoAccessHelper;
  private listening: boolean = false;
  private readonly mediaChangeCallback: (change: photoAccessHelper.PhotoAssetChangeInfos) => void;

  constructor(context: common.UIAbilityContext, repository: CapabilityProbeRepository) {
    this.context = context;
    this.repository = repository;
    this.mediaHelper = photoAccessHelper.getPhotoAccessHelper(context);
    this.mediaChangeCallback = (change: photoAccessHelper.PhotoAssetChangeInfos): void => {
      this.recordMediaChange(change);
    };
  }

  async recordLifecycle(detail: string): Promise<void> {
    await this.record({
      kind: ProbeEventKind.LIFECYCLE,
      recordedAtMs: Date.now(),
      detail: detail
    });
  }

  async recordWant(want: Want): Promise<string> {
    const parameters: ProbeWantParameters | undefined = want.parameters as ProbeWantParameters | undefined;
    const cardId: string = extractProbeCardId(parameters);
    await this.record({
      kind: ProbeEventKind.DEEP_LINK,
      recordedAtMs: Date.now(),
      detail: cardId.length > 0 ? `WantAgent cardId=${cardId}` : 'WantAgent 未携带有效 cardId'
    });
    return cardId;
  }

  async requestMediaPermission(): Promise<string> {
    try {
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(this.context, [READ_IMAGEVIDEO]);
      const code: number = result.authResults.length > 0 ? result.authResults[0] : -1;
      const granted: boolean = code === 0;
      const detail: string = `READ_IMAGEVIDEO request code=${code}; granted=${granted}`;
      await this.record({ kind: ProbeEventKind.PERMISSION, recordedAtMs: Date.now(), detail: detail });
      return detail;
    } catch (error) {
      const detail: string = `READ_IMAGEVIDEO request errorCode=${errorCode(error as Object)}`;
      await this.record({ kind: ProbeEventKind.ERROR, recordedAtMs: Date.now(), detail: detail });
      return detail;
    }
  }

  async checkMediaPermission(): Promise<string> {
    try {
      const status: abilityAccessCtrl.GrantStatus = await abilityAccessCtrl.createAtManager()
        .checkAccessToken(this.context.applicationInfo.accessTokenId, READ_IMAGEVIDEO);
      const granted: boolean = status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      const detail: string = `READ_IMAGEVIDEO check status=${status}; granted=${granted}`;
      await this.record({ kind: ProbeEventKind.PERMISSION, recordedAtMs: Date.now(), detail: detail });
      return detail;
    } catch (error) {
      const detail: string = `READ_IMAGEVIDEO check errorCode=${errorCode(error as Object)}`;
      await this.record({ kind: ProbeEventKind.ERROR, recordedAtMs: Date.now(), detail: detail });
      return detail;
    }
  }

  async startMediaListener(): Promise<string> {
    if (this.listening) {
      return 'photoChange 已在监听';
    }
    try {
      this.mediaHelper.on('photoChange', this.mediaChangeCallback);
      this.listening = true;
      const detail: string = 'photoChange listener=STARTED';
      await this.record({ kind: ProbeEventKind.MEDIA_CHANGE, recordedAtMs: Date.now(), detail: detail });
      return detail;
    } catch (error) {
      const detail: string = `photoChange start errorCode=${errorCode(error as Object)}`;
      await this.record({ kind: ProbeEventKind.ERROR, recordedAtMs: Date.now(), detail: detail });
      return detail;
    }
  }

  async stopMediaListener(): Promise<string> {
    if (!this.listening) {
      return 'photoChange 当前未监听';
    }
    try {
      this.mediaHelper.off('photoChange', this.mediaChangeCallback);
      this.listening = false;
      const detail: string = 'photoChange listener=STOPPED';
      await this.record({ kind: ProbeEventKind.MEDIA_CHANGE, recordedAtMs: Date.now(), detail: detail });
      return detail;
    } catch (error) {
      const detail: string = `photoChange stop errorCode=${errorCode(error as Object)}`;
      await this.record({ kind: ProbeEventKind.ERROR, recordedAtMs: Date.now(), detail: detail });
      return detail;
    }
  }

  async recordLatestMediaTrial(kind: ProbeMediaTrialKind): Promise<string> {
    let result: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | undefined;
    try {
      const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      predicates.orderByDesc(photoAccessHelper.PhotoKeys.DATE_ADDED_MS);
      predicates.limit(MAX_LATEST_ASSETS, 0);
      const options: photoAccessHelper.FetchOptions = {
        fetchColumns: [
          photoAccessHelper.PhotoKeys.SIZE,
          photoAccessHelper.PhotoKeys.DATE_ADDED_MS,
          photoAccessHelper.PhotoKeys.DATE_TAKEN_MS,
          photoAccessHelper.PhotoKeys.PHOTO_SUBTYPE
        ],
        predicates: predicates
      };
      result = await this.mediaHelper.getAssets(options);
      const assets: photoAccessHelper.PhotoAsset[] = await result.getAllObjects();
      if (assets.length === 0) {
        const emptyDetail: string = `trial=${kind}; latestAsset=EMPTY`;
        await this.record({ kind: ProbeEventKind.MEDIA_QUERY, recordedAtMs: Date.now(), detail: emptyDetail });
        return emptyDetail;
      }
      const asset: photoAccessHelper.PhotoAsset = assets[0];
      const size: photoAccessHelper.MemberType = asset.get(photoAccessHelper.PhotoKeys.SIZE);
      const dateAdded: photoAccessHelper.MemberType = asset.get(photoAccessHelper.PhotoKeys.DATE_ADDED_MS);
      const dateTaken: photoAccessHelper.MemberType = asset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN_MS);
      const subtype: photoAccessHelper.MemberType = asset.get(photoAccessHelper.PhotoKeys.PHOTO_SUBTYPE);
      const detail: string = `trial=${kind}; subtype=${subtype}`;
      await this.record({
        kind: ProbeEventKind.MEDIA_QUERY,
        recordedAtMs: Date.now(),
        detail: detail,
        uri: asset.uri,
        displayName: asset.displayName,
        mediaType: photoTypeLabel(asset.photoType),
        byteCount: typeof size === 'number' ? size : undefined,
        dateAddedMs: typeof dateAdded === 'number' ? dateAdded : undefined,
        dateTakenMs: typeof dateTaken === 'number' ? dateTaken : undefined
      });
      return `${detail}; 已记录最新媒体的脱敏字段`;
    } catch (error) {
      const detail: string = `trial=${kind}; getAssets errorCode=${errorCode(error as Object)}`;
      await this.record({ kind: ProbeEventKind.ERROR, recordedAtMs: Date.now(), detail: detail });
      return detail;
    } finally {
      try {
        result?.close();
      } catch (_error) {
      }
    }
  }

  async queryRecentScreenshot(): Promise<string> {
    try {
      const options: photoAccessHelper.RecentPhotoOptions = new photoAccessHelper.RecentPhotoOptions();
      options.period = 300;
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.photoSource = photoAccessHelper.PhotoSource.SCREENSHOT;
      const info: photoAccessHelper.RecentPhotoInfo = await this.mediaHelper.getRecentPhotoInfo(options);
      const detail: string = info.identifier === undefined ? 'recentScreenshot identifier=EMPTY' :
        'recentScreenshot identifier=PRESENT';
      await this.record({
        kind: ProbeEventKind.MEDIA_QUERY,
        recordedAtMs: Date.now(),
        detail: detail,
        identifier: info.identifier,
        dateTakenMs: info.dateTaken
      });
      return detail;
    } catch (error) {
      const detail: string = `recentScreenshot errorCode=${errorCode(error as Object)}`;
      await this.record({ kind: ProbeEventKind.ERROR, recordedAtMs: Date.now(), detail: detail });
      return detail;
    }
  }

  async requestNotificationPermission(): Promise<string> {
    try {
      await notificationManager.requestEnableNotification(this.context);
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      const detail: string = `notification enabled=${enabled}`;
      await this.record({ kind: ProbeEventKind.NOTIFICATION, recordedAtMs: Date.now(), detail: detail });
      return detail;
    } catch (error) {
      const enabled: boolean = await safeNotificationEnabled();
      const detail: string = `notification request errorCode=${errorCode(error as Object)}; enabled=${enabled}`;
      await this.record({ kind: ProbeEventKind.ERROR, recordedAtMs: Date.now(), detail: detail });
      return detail;
    }
  }

  async publishDeepLinkNotification(): Promise<string> {
    try {
      const parameters: Record<string, Object> =
        JSON.parse(`{"cardId":"${PROBE_CARD_ID}"}`) as Record<string, Object>;
      const target: Want = {
        bundleName: this.context.abilityInfo.bundleName,
        abilityName: this.context.abilityInfo.name,
        parameters: parameters
      };
      const agentInfo: wantAgent.WantAgentInfo = {
        wants: [target],
        requestCode: PROBE_NOTIFICATION_ID,
        actionType: wantAgent.OperationType.START_ABILITY,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(agentInfo);
      const normal: notificationManager.NotificationBasicContent = {
        title: '拾光 · Story 3 能力探针',
        text: `点击验证 WantAgent cardId=${PROBE_CARD_ID}`
      };
      const content: notificationManager.NotificationContent = {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: normal
      };
      const request: notificationManager.NotificationRequest = {
        id: PROBE_NOTIFICATION_ID,
        content: content,
        wantAgent: agent,
        tapDismissed: true
      };
      await notificationManager.publish(request);
      const detail: string = `notification published id=${PROBE_NOTIFICATION_ID}; cardId=${PROBE_CARD_ID}`;
      await this.record({ kind: ProbeEventKind.NOTIFICATION, recordedAtMs: Date.now(), detail: detail });
      return detail;
    } catch (error) {
      const detail: string = `notification publish errorCode=${errorCode(error as Object)}`;
      await this.record({ kind: ProbeEventKind.ERROR, recordedAtMs: Date.now(), detail: detail });
      return detail;
    }
  }

  async listEvents(): Promise<ProbeEvidenceEvent[]> {
    return await this.repository.list();
  }

  async clearEvents(): Promise<void> {
    await this.repository.clear();
  }

  isListening(): boolean {
    return this.listening;
  }

  private async record(input: ProbeEvidenceInput): Promise<void> {
    await this.repository.append(input);
  }

  private recordMediaChange(change: photoAccessHelper.PhotoAssetChangeInfos): void {
    const changes: photoAccessHelper.PhotoAssetChangeData[] = change.assetChangeDatas ?? [];
    if (changes.length === 0) {
      this.record({
        kind: ProbeEventKind.MEDIA_CHANGE,
        recordedAtMs: Date.now(),
        detail: `photoChange type=${change.type}; recheck=${change.isForRecheck}; assets=0`
      }).catch((): void => {});
      return;
    }
    changes.forEach((item: photoAccessHelper.PhotoAssetChangeData): void => {
      const after: photoAccessHelper.PhotoAssetChangeInfo | null = item.assetAfterChange;
      this.record({
        kind: ProbeEventKind.MEDIA_CHANGE,
        recordedAtMs: Date.now(),
        detail: `photoChange type=${change.type}; recheck=${change.isForRecheck}; deleted=${item.isDeleted}; ` +
          `contentChanged=${item.isContentChanged}`,
        uri: after === null ? undefined : after.uri,
        albumUri: after === null ? undefined : after.albumUri,
        mediaType: after === null ? undefined : photoTypeLabel(after.mediaType)
      }).catch((): void => {});
    });
  }
}

let sharedController: CapabilityProbeController | undefined;

export function getCapabilityProbeController(context: common.UIAbilityContext): CapabilityProbeController {
  if (sharedController === undefined) {
    sharedController = new CapabilityProbeController(context, new CapabilityProbeRepository(context));
  }
  return sharedController;
}

function photoTypeLabel(type: photoAccessHelper.PhotoType): string {
  if (type === photoAccessHelper.PhotoType.IMAGE) {
    return 'IMAGE';
  }
  if (type === photoAccessHelper.PhotoType.VIDEO) {
    return 'VIDEO';
  }
  return `UNKNOWN_${type}`;
}

function errorCode(error: Object): string {
  const businessError: BusinessError = error as BusinessError;
  return typeof businessError.code === 'number' ? `${businessError.code}` : 'UNAVAILABLE';
}

async function safeNotificationEnabled(): Promise<boolean> {
  try {
    return await notificationManager.isNotificationEnabled();
  } catch (_error) {
    return false;
  }
}
