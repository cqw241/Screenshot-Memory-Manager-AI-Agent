import { common } from '@kit.AbilityKit';
import { ProbeEvidenceEvent } from '../models/CapabilityProbeModels';
import {
  CapabilityProbeController,
  getCapabilityProbeController,
  ProbeMediaTrialKind
} from '../services/CapabilityProbeController';

interface CapabilityProbeRouteParams {
  cardId?: string;
}

@Entry
@Component
struct CapabilityProbe {
  @State private events: ProbeEvidenceEvent[] = [];
  @State private status: string = '尚未执行探针操作';
  @State private busy: boolean = false;
  @State private listening: boolean = false;
  @State private receivedCardId: string = '';

  private controller?: CapabilityProbeController;

  aboutToAppear(): void {
    const context: common.UIAbilityContext | undefined =
      this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context === undefined) {
      this.status = '探针页面无法取得 UIAbility 上下文';
      return;
    }
    this.controller = getCapabilityProbeController(context);
    const params: CapabilityProbeRouteParams | undefined =
      this.getUIContext().getRouter().getParams() as CapabilityProbeRouteParams | undefined;
    if (params !== undefined && typeof params.cardId === 'string') {
      this.receivedCardId = params.cardId;
    } else {
      const stored: string | undefined = AppStorage.get<string>('probeDeepLinkCardId');
      this.receivedCardId = stored ?? '';
    }
    this.refreshEvents();
  }

  private async runAction(action: () => Promise<string>): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      this.status = await action();
      this.listening = this.controller?.isListening() ?? false;
      await this.refreshEvents();
    } catch (_error) {
      this.status = '探针操作失败；详情仅以脱敏错误码写入记录';
    } finally {
      this.busy = false;
    }
  }

  private async refreshEvents(): Promise<void> {
    if (this.controller === undefined) {
      return;
    }
    try {
      this.events = (await this.controller.listEvents()).slice().reverse();
    } catch (_error) {
      this.status = '无法读取本地探针记录';
    }
  }

  private async clearEvents(): Promise<void> {
    if (this.controller === undefined || this.busy) {
      return;
    }
    this.busy = true;
    try {
      await this.controller.clearEvents();
      this.events = [];
      this.status = '本机探针记录已清空';
    } catch (_error) {
      this.status = '无法清空本机探针记录';
    } finally {
      this.busy = false;
    }
  }

  private async returnToApp(): Promise<void> {
    try {
      await this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
    } catch (_error) {
      this.status = '暂时无法返回应用首页';
    }
  }

  private eventText(event: ProbeEvidenceEvent): string {
    let value: string = `${new Date(event.recordedAtMs).toLocaleString()} · ${event.kind}\n${event.detail}`;
    if (event.mediaType !== undefined) {
      value += `\nmediaType=${event.mediaType}`;
    }
    if (event.byteCount !== undefined) {
      value += ` · bytes=${event.byteCount}`;
    }
    if (event.dateAddedMs !== undefined) {
      value += ` · dateAdded=${event.dateAddedMs}`;
    }
    if (event.dateTakenMs !== undefined) {
      value += ` · dateTaken=${event.dateTakenMs}`;
    }
    if (event.uriDigest !== undefined) {
      value += `\nuri.sha256=${event.uriDigest}`;
    }
    if (event.identifierDigest !== undefined) {
      value += `\nidentifier.sha256=${event.identifierDigest}`;
    }
    if (event.albumDigest !== undefined) {
      value += `\nalbum.sha256=${event.albumDigest}`;
    }
    if (event.displayNameDigest !== undefined) {
      value += `\nname.sha256=${event.displayNameDigest}`;
    }
    return value;
  }

  @Builder
  private ProbeButton(label: string, action: () => void) {
    Button(label)
      .fontSize(12)
      .fontColor('#FFFDF8')
      .backgroundColor(this.busy ? '#8A918B' : '#2C4438')
      .borderRadius(12)
      .height(42)
      .layoutWeight(1)
      .enabled(!this.busy)
      .onClick(action)
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text('STORY 3 · CAPABILITY PROBE')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#A65B24')
                .letterSpacing(1.1)
              Text('平台能力探针')
                .fontSize(27)
                .fontWeight(FontWeight.Bold)
                .fontColor('#20201D')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Button('返回')
              .fontSize(12)
              .fontColor('#2C4438')
              .backgroundColor('#E7EEE8')
              .borderRadius(12)
              .onClick(() => this.returnToApp())
          }
          .width('100%')

          Text('仅用于平台验真。当前模拟器结果不能判定 L0/L1/L2，也不会启动自动摄取。媒体标识和文件名仅以 SHA-256 摘要落盘。')
            .fontSize(13)
            .fontColor('#6E685F')
            .lineHeight(20)
            .width('100%')
            .padding(14)
            .backgroundColor('#FFF4E7')
            .borderRadius(14)

          if (this.receivedCardId.length > 0) {
            Text(`WantAgent 收到 cardId：${this.receivedCardId}`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2C6A4E')
              .width('100%')
              .padding(12)
              .backgroundColor('#E8F1EA')
              .borderRadius(12)
          }

          Text(this.status)
            .fontSize(12)
            .fontColor('#4F4B44')
            .width('100%')
            .padding(12)
            .backgroundColor('#FFFDF8')
            .border({ width: 1, color: '#E2DBCE' })
            .borderRadius(12)

          Text('权限与监听')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#292823')
            .width('100%')
          Row({ space: 8 }) {
            this.ProbeButton('申请相册权限', () => this.runAction(async (): Promise<string> =>
              await this.controller!.requestMediaPermission()))
            this.ProbeButton('检查权限', () => this.runAction(async (): Promise<string> =>
              await this.controller!.checkMediaPermission()))
          }
          .width('100%')
          Row({ space: 8 }) {
            this.ProbeButton('开始 photoChange', () => this.runAction(async (): Promise<string> =>
              await this.controller!.startMediaListener()))
            this.ProbeButton('停止监听', () => this.runAction(async (): Promise<string> =>
              await this.controller!.stopMediaListener()))
          }
          .width('100%')

          Text(`监听状态：${this.listening ? '已注册' : '未注册'}`)
            .fontSize(11)
            .fontColor('#777168')
            .width('100%')

          Text('媒体矩阵 · 每种执行 3 次')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#292823')
            .width('100%')
          Text('先制造对应媒体，再点击同名按钮记录最新媒体。四类按钮不会触发 OCR、模型或卡片创建。')
            .fontSize(12)
            .fontColor('#777168')
            .lineHeight(18)
            .width('100%')
          Row({ space: 8 }) {
            this.ProbeButton('记录截图', () => this.runAction(async (): Promise<string> =>
              await this.controller!.recordLatestMediaTrial(ProbeMediaTrialKind.SCREENSHOT)))
            this.ProbeButton('记录拍照', () => this.runAction(async (): Promise<string> =>
              await this.controller!.recordLatestMediaTrial(ProbeMediaTrialKind.CAMERA)))
          }
          .width('100%')
          Row({ space: 8 }) {
            this.ProbeButton('记录下载', () => this.runAction(async (): Promise<string> =>
              await this.controller!.recordLatestMediaTrial(ProbeMediaTrialKind.DOWNLOAD)))
            this.ProbeButton('记录普通保存', () => this.runAction(async (): Promise<string> =>
              await this.controller!.recordLatestMediaTrial(ProbeMediaTrialKind.SAVED_IMAGE)))
          }
          .width('100%')
          Row({ space: 8 }) {
            this.ProbeButton('查询最近截图来源', () => this.runAction(async (): Promise<string> =>
              await this.controller!.queryRecentScreenshot()))
          }
          .width('100%')

          Text('通知与 WantAgent')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#292823')
            .width('100%')
          Row({ space: 8 }) {
            this.ProbeButton('申请通知授权', () => this.runAction(async (): Promise<string> =>
              await this.controller!.requestNotificationPermission()))
            this.ProbeButton('发布深链通知', () => this.runAction(async (): Promise<string> =>
              await this.controller!.publishDeepLinkNotification()))
          }
          .width('100%')

          Row() {
            Text(`本地脱敏记录 · ${this.events.length} 条`)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#292823')
            Blank()
            Button('刷新')
              .fontSize(11)
              .onClick(() => this.refreshEvents())
            Button('清空')
              .fontSize(11)
              .fontColor('#8A4A2B')
              .backgroundColor('#FFF1E7')
              .onClick(() => this.clearEvents())
          }
          .width('100%')

          ForEach(this.events, (event: ProbeEvidenceEvent) => {
            Text(this.eventText(event))
              .fontSize(10)
              .fontColor('#4F4B44')
              .fontFamily('monospace')
              .lineHeight(16)
              .width('100%')
              .padding(12)
              .backgroundColor('#FFFDF8')
              .border({ width: 1, color: '#E8E2D5' })
              .borderRadius(12)
          }, (event: ProbeEvidenceEvent): string => `${event.recordedAtMs}-${event.kind}-${event.detail}`)
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 24, bottom: 30 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2EFE7')
  }
}
