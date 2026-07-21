import { common } from '@kit.AbilityKit';
import {
  CODING_ENDPOINTS,
  EndpointTemplate,
  isKnownOfficialOrigin,
  isLoopbackHttpOrigin,
  ModelSuggestion,
  MULTIMODAL_ENDPOINTS,
  RECOMMENDED_MODELS,
  targetHost
} from '../models/EndpointCatalog';
import { AppPage, StartupRoute } from '../models/AppFlow';
import { VerifiedConfigMetadata } from '../models/ModelConfig';
import {
  ImportOutcome,
  ImportOutcomeKind,
  OcrStatus,
  ReadyImportOutcome
} from '../models/ScreenshotImportModels';
import {
  ParseStatus,
  StructuredUnderstanding,
  UnderstandingError,
  UnderstandingOutcome
} from '../models/StructuredUnderstandingModels';
import {
  VerificationCandidate,
  VerificationConfirmations,
  VerificationError,
  VerificationErrorCategory,
  VerificationSuccess
} from '../models/VerificationModels';
import { ConfigVerificationCoordinator } from '../services/ConfigVerificationCoordinator';
import { ConfigRepository } from '../services/ConfigRepository';
import { createConfigRepository } from '../services/ConfigRepositoryFactory';
import { HarmonyHttpTransport } from '../services/HarmonyHttpTransport';
import { HarmonyOcrSessionFactory } from '../services/HarmonyOcrSession';
import { HarmonyPhotoSelection } from '../services/HarmonyPhotoSelection';
import { HarmonyPrivateImageStore } from '../services/HarmonyPrivateImageStore';
import { HarmonyThumbnailGenerator } from '../services/HarmonyThumbnailGenerator';
import {
  HarmonyUnderstandingClock,
  HarmonyUnderstandingMetricsLogger
} from '../services/HarmonyUnderstandingRuntime';
import { ImportConsentRepository } from '../services/ImportConsentRepository';
import { ScreenshotImportService } from '../services/ScreenshotImportService';
import { ScreenshotUnderstandingService } from '../services/ScreenshotUnderstandingService';
import { parseOrigin } from '../services/UrlPreflight';
import { VisionVerificationGate } from '../services/VisionVerificationGate';
import { StartupRouter } from '../services/StartupRouter';

@Entry
@Component
struct Index {
  @State private currentPage: AppPage = AppPage.LOADING;
  @State private recoveryRequired: boolean = false;
  @State private baseURL: string = '';
  @State private apiKey: string = '';
  @State private model: string = '';
  @State private hasSavedKey: boolean = false;
  @State private advancedExpanded: boolean = false;
  @State private customSourceTrusted: boolean = false;
  @State private loopbackWarningAccepted: boolean = false;
  @State private isLoading: boolean = false;
  @State private errorCategory: string = '';
  @State private errorMessage: string = '';
  @State private verificationSucceeded: boolean = false;
  @State private activeModel: string = '';
  @State private isImporting: boolean = false;
  @State private importStatus: string = '';
  @State private importedImageUri: string = '';
  @State private importedImageSummary: string = '';
  @State private ocrPreview: string = '';
  @State private ocrNeedsRetry: boolean = false;
  @State private thumbnailUri: string = '';
  @State private thumbnailSummary: string = '';
  @State private understandingType: string = '';
  @State private understandingTimeText: string = '';
  @State private understandingEventTime: string = '';
  @State private understandingLocation: string = '';
  @State private understandingCode: string = '';
  @State private understandingAmount: string = '';
  @State private understandingActions: string = '';
  @State private understandingParseStatus: string = '';
  @State private understandingErrorCategory: string = '';

  private repository?: ConfigRepository;
  private coordinator?: ConfigVerificationCoordinator;
  private importService?: ScreenshotImportService;
  private understandingService?: ScreenshotUnderstandingService;
  private importConsent?: ImportConsentRepository;

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.repository = createConfigRepository(context);
    this.coordinator = new ConfigVerificationCoordinator(
      new VisionVerificationGate(new HarmonyHttpTransport()),
      this.repository
    );
    this.importService = new ScreenshotImportService(
      new HarmonyPhotoSelection(),
      new HarmonyPrivateImageStore(context),
      new HarmonyOcrSessionFactory()
    );
    this.understandingService = new ScreenshotUnderstandingService(
      this.repository,
      new HarmonyThumbnailGenerator(context),
      new HarmonyHttpTransport(),
      new HarmonyUnderstandingClock(),
      new HarmonyUnderstandingMetricsLogger()
    );
    this.importConsent = new ImportConsentRepository(context);
    this.resolveStartupRoute();
  }

  private async resolveStartupRoute(): Promise<void> {
    if (this.repository === undefined) {
      return;
    }
    const route: StartupRoute = await new StartupRouter(this.repository).resolve();
    this.recoveryRequired = route.recoveryRequired;
    if (route.page === AppPage.HOME) {
      await this.loadHomeMetadata();
    } else {
      this.resetDraft();
      this.currentPage = route.page;
    }
  }

  private async loadHomeMetadata(): Promise<void> {
    if (this.repository === undefined) {
      return;
    }
    try {
      const metadata: VerifiedConfigMetadata | undefined = await this.repository.getMetadata();
      if (metadata !== undefined) {
        this.activeModel = metadata.model;
        this.currentPage = AppPage.HOME;
      } else {
        this.recoveryRequired = true;
        this.resetDraft();
        this.currentPage = AppPage.WIZARD;
      }
    } catch (_error) {
      this.recoveryRequired = true;
      this.resetDraft();
      this.currentPage = AppPage.WIZARD;
    }
  }

  private async requestScreenshotImport(): Promise<void> {
    if (this.isImporting || this.repository === undefined || this.importConsent === undefined) {
      return;
    }
    try {
      const metadata: VerifiedConfigMetadata | undefined = await this.repository.getMetadata();
      if (metadata === undefined) {
        this.importStatus = '已验证配置不可用，请先重新配置模型。';
        return;
      }
      if (await this.importConsent.hasConsent(metadata.trustedOrigin)) {
        await this.runScreenshotImport();
        return;
      }
      this.showImportConsent(metadata.trustedOrigin, targetHost(metadata.baseURL));
    } catch (_error) {
      this.importStatus = '无法读取导入授权状态，请稍后重试。';
    }
  }

  private showImportConsent(origin: string, host: string): void {
    this.getUIContext().showAlertDialog({
      title: '发送截图前确认',
      message: `拾光会先在设备端识别文字，再把 OCR 文本和长边不超过 1024px 的缩略图发送到 ${host}。原图不会上传。是否继续？`,
      primaryButton: {
        value: '同意并选择图片',
        fontColor: '#2C4438',
        action: () => {
          this.grantConsentAndImport(origin);
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: '#77736A',
        action: () => {
        }
      }
    });
  }

  private async grantConsentAndImport(origin: string): Promise<void> {
    if (this.importConsent === undefined) {
      return;
    }
    try {
      await this.importConsent.grant(origin);
      await this.runScreenshotImport();
    } catch (_error) {
      this.importStatus = '未能保存发送确认，请稍后重试。';
    }
  }

  private async runScreenshotImport(): Promise<void> {
    if (this.importService === undefined || this.understandingService === undefined || this.isImporting) {
      return;
    }
    this.isImporting = true;
    this.importStatus = '正在选择图片并进行端侧文字识别…';
    this.ocrNeedsRetry = false;
    this.resetUnderstandingPreview();
    try {
      const outcome: ImportOutcome = await this.importService.importSingle();
      if (outcome.kind === ImportOutcomeKind.CANCELLED) {
        this.importStatus = '已取消选择，没有导入任何图片。';
        return;
      }
      const ready: ReadyImportOutcome = outcome as ReadyImportOutcome;
      this.importedImageUri = ready.image.uri;
      this.importedImageSummary = `${ready.image.width} × ${ready.image.height} · ${ready.image.byteCount} bytes`;
      this.ocrPreview = ready.ocrText;
      this.ocrNeedsRetry = ready.ocrStatus === OcrStatus.RETRY_PENDING;
      this.importStatus = this.ocrNeedsRetry ?
        '端侧 OCR 未识别到文字，正在使用安全缩略图继续理解…' :
        '端侧 OCR 已完成，正在生成安全缩略图并理解内容…';
      try {
        const understandingOutcome: UnderstandingOutcome =
          await this.understandingService.understand(ready.image, ready.ocrText);
        this.applyUnderstandingOutcome(understandingOutcome);
        this.importStatus = understandingOutcome.understanding.parseStatus === ParseStatus.FALLBACK_INVALID_RESPONSE ?
          '模型两次返回的内容均不符合契约，已安全回退为未分类结果。' :
          '缩略图与结构化理解已完成。';
      } catch (error) {
        if (error instanceof UnderstandingError) {
          this.understandingErrorCategory = error.category;
          this.importStatus = `${error.category}：${error.userMessage}`;
        } else {
          this.understandingErrorCategory = '服务错误';
          this.importStatus = '服务错误：模型理解暂时不可用，请稍后重试。';
        }
      }
    } catch (_error) {
      this.importStatus = '导入失败。请确认图片可读取后重试。';
      this.ocrNeedsRetry = false;
    } finally {
      this.isImporting = false;
    }
  }

  private resetUnderstandingPreview(): void {
    this.thumbnailUri = '';
    this.thumbnailSummary = '';
    this.understandingType = '';
    this.understandingTimeText = '';
    this.understandingEventTime = '';
    this.understandingLocation = '';
    this.understandingCode = '';
    this.understandingAmount = '';
    this.understandingActions = '';
    this.understandingParseStatus = '';
    this.understandingErrorCategory = '';
  }

  private applyUnderstandingOutcome(outcome: UnderstandingOutcome): void {
    const result: StructuredUnderstanding = outcome.understanding;
    this.thumbnailUri = outcome.thumbnail.uri;
    this.thumbnailSummary = `${outcome.thumbnail.width} × ${outcome.thumbnail.height} · ` +
      `${outcome.thumbnail.byteCount} bytes · JPEG 85`;
    this.understandingType = result.type;
    this.understandingTimeText = result.entities.timeText ?? '';
    this.understandingEventTime = result.entities.eventTime ?? '';
    this.understandingLocation = result.entities.location ?? '';
    this.understandingCode = result.entities.code ?? '';
    this.understandingAmount = result.entities.amount ?? '';
    this.understandingActions = result.actions.length > 0 ? result.actions.join(' · ') : '无';
    this.understandingParseStatus = result.parseStatus;
    this.understandingErrorCategory = '';
  }

  private resetDraft(): void {
    this.baseURL = '';
    this.apiKey = '';
    this.model = '';
    this.hasSavedKey = false;
    this.advancedExpanded = false;
    this.resetOriginConfirmations();
    this.clearError();
  }

  private async openSettings(): Promise<void> {
    if (this.repository === undefined) {
      return;
    }
    try {
      const metadata: VerifiedConfigMetadata | undefined = await this.repository.getMetadata();
      if (metadata === undefined) {
        this.recoveryRequired = true;
        this.resetDraft();
        this.currentPage = AppPage.WIZARD;
        return;
      }
      this.baseURL = metadata.baseURL;
      this.apiKey = '';
      this.model = metadata.model;
      this.hasSavedKey = true;
      this.customSourceTrusted = !isKnownOfficialOrigin(metadata.baseURL) &&
        metadata.trustedOrigin === parseOrigin(metadata.baseURL);
      this.loopbackWarningAccepted = false;
      this.clearError();
      this.currentPage = AppPage.SETTINGS;
    } catch (_error) {
      this.recoveryRequired = true;
      this.resetDraft();
      this.currentPage = AppPage.WIZARD;
    }
  }

  private cancelSettings(): void {
    if (this.isLoading) {
      return;
    }
    this.resetDraft();
    this.currentPage = AppPage.HOME;
  }

  private useTemplate(template: EndpointTemplate): void {
    this.baseURL = template.baseURL;
    this.resetOriginConfirmations();
    this.clearError();
  }

  private resetOriginConfirmations(): void {
    this.customSourceTrusted = false;
    this.loopbackWarningAccepted = false;
  }

  private clearError(): void {
    this.errorCategory = '';
    this.errorMessage = '';
    this.verificationSucceeded = false;
  }

  private isCustomSource(): boolean {
    return this.baseURL.trim().length > 0 && !isKnownOfficialOrigin(this.baseURL) && !isLoopbackHttpOrigin(this.baseURL);
  }

  private isFormReady(): boolean {
    const fieldsComplete: boolean = parseOrigin(this.baseURL).length > 0 &&
      (this.apiKey.length > 0 || this.hasSavedKey) && this.model.trim().length > 0;
    const trustReady: boolean = !this.isCustomSource() || this.customSourceTrusted;
    const loopbackReady: boolean = !isLoopbackHttpOrigin(this.baseURL) || this.loopbackWarningAccepted;
    return fieldsComplete && trustReady && loopbackReady && !this.isLoading;
  }

  private async startVerification(): Promise<void> {
    if (!this.isFormReady() || this.repository === undefined || this.coordinator === undefined) {
      return;
    }
    this.clearError();
    this.isLoading = true;
    const confirmations: VerificationConfirmations = {
      customOriginTrusted: this.customSourceTrusted,
      loopbackHttpAccepted: this.loopbackWarningAccepted
    };
    try {
      let success: VerificationSuccess;
      if (this.apiKey.length > 0) {
        success = await this.verifyWithKey(this.apiKey, confirmations);
      } else {
        success = await this.repository.withVerifiedConfig(async (stored) => {
          return await this.verifyWithKey(stored.apiKey, confirmations);
        });
      }
      this.baseURL = success.normalizedBaseURL;
      this.apiKey = '';
      this.hasSavedKey = true;
      this.customSourceTrusted = !isKnownOfficialOrigin(success.normalizedBaseURL);
      this.verificationSucceeded = true;
      this.activeModel = this.model.trim();
      this.recoveryRequired = false;
      this.currentPage = AppPage.HOME;
    } catch (error) {
      if (error instanceof VerificationError) {
        this.errorCategory = error.category;
        this.errorMessage = error.userMessage;
      } else {
        this.errorCategory = VerificationErrorCategory.SERVICE;
        this.errorMessage = '视觉验证已完成，但配置未能安全保存。旧配置未受影响，请重试。';
      }
    } finally {
      this.isLoading = false;
    }
  }

  private async verifyWithKey(apiKey: string,
    confirmations: VerificationConfirmations): Promise<VerificationSuccess> {
    if (this.coordinator === undefined) {
      throw new Error('Verification coordinator is unavailable');
    }
    const candidate: VerificationCandidate = {
      baseURL: this.baseURL,
      apiKey: apiKey,
      model: this.model
    };
    try {
      return await this.coordinator.verifyAndSave(candidate, confirmations);
    } finally {
      candidate.apiKey = '';
    }
  }

  @Builder
  private SectionHeading(kicker: string, title: string, detail: string) {
    Column({ space: 5 }) {
      Text(kicker)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#A65B24')
        .letterSpacing(1.2)
      Text(title)
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor('#20201D')
      Text(detail)
        .fontSize(13)
        .fontColor('#73716A')
        .lineHeight(20)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private EndpointButtons(items: EndpointTemplate[]) {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
      ForEach(items, (item: EndpointTemplate) => {
        Button(item.label)
          .fontSize(13)
          .fontColor(this.baseURL === item.baseURL ? '#FFFDF8' : '#3D3B35')
          .backgroundColor(this.baseURL === item.baseURL ? '#2C4438' : '#F2EFE7')
          .borderRadius(12)
          .height(38)
          .margin({ right: 8, bottom: 8 })
          .onClick(() => this.useTemplate(item))
      }, (item: EndpointTemplate) => item.baseURL)
    }
    .width('100%')
  }

  @Builder
  private FieldLabel(title: string, hint: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2D2C28')
      Blank()
      Text(hint)
        .fontSize(11)
        .fontColor('#99968D')
    }
    .width('100%')
  }

  @Builder
  private TrustNotice() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Text('外部')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#75441D')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#F6DEC6')
          .borderRadius(8)
        Text(`确认信任 ${targetHost(this.baseURL)}`)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#35291F')
      }
      Text('API Key 与一张本地视觉挑战图将发送给此服务。确认服务来源及隐私条款后再继续。')
        .fontSize(13)
        .fontColor('#6E5541')
        .lineHeight(20)
      Row({ space: 8 }) {
        Checkbox({ name: 'custom-source-trust', group: 'origin-confirmations' })
          .select(this.customSourceTrusted)
          .selectedColor('#A65B24')
          .onChange((value: boolean) => this.customSourceTrusted = value)
        Text('我信任这个服务源，并同意发送上述数据')
          .fontSize(13)
          .fontColor('#49382B')
          .onClick(() => this.customSourceTrusted = !this.customSourceTrusted)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFF4E8')
    .border({ width: 1, color: '#E6BD98' })
    .borderRadius(16)
  }

  @Builder
  private LoopbackNotice() {
    Column({ space: 10 }) {
      Text('本地 HTTP 连接未加密')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#743A2B')
      Text('仅适合本机开发调试。网络中的其他程序可能读取 API Key 与挑战图，请勿用于远程服务。')
        .fontSize(13)
        .fontColor('#7B554B')
        .lineHeight(20)
      Row({ space: 8 }) {
        Checkbox({ name: 'loopback-http-warning', group: 'origin-confirmations' })
          .select(this.loopbackWarningAccepted)
          .selectedColor('#A84832')
          .onChange((value: boolean) => this.loopbackWarningAccepted = value)
        Text('我了解风险，仍要验证本机服务')
          .fontSize(13)
          .fontColor('#5C3A31')
          .onClick(() => this.loopbackWarningAccepted = !this.loopbackWarningAccepted)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFF0EC')
    .border({ width: 1, color: '#E3A596' })
    .borderRadius(16)
  }

  @Builder
  private ErrorPanel() {
    Row({ space: 12 }) {
      Text('!')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFDF8')
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .backgroundColor('#A84832')
        .borderRadius(15)
      Column({ space: 3 }) {
        Text(this.errorCategory)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#5E2E23')
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor('#7A4A3E')
          .lineHeight(19)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding(15)
    .backgroundColor('#FFF0EC')
    .borderRadius(16)
  }

  @Builder
  private SuccessPanel() {
    Row({ space: 12 }) {
      Text('✓')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFDF8')
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .backgroundColor('#2C6A4E')
        .borderRadius(15)
      Column({ space: 3 }) {
        Text('视觉验证通过')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#214D3A')
        Text('新配置已通过事务式替换安全保存。')
          .fontSize(13)
          .fontColor('#416D59')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(15)
    .backgroundColor('#EAF5EE')
    .borderRadius(16)
  }

  @Builder
  private WizardPage() {
    Scroll() {
      Column({ space: 24 }) {
        if (this.currentPage === AppPage.SETTINGS) {
          Row() {
            Button('取消')
              .fontSize(13)
              .fontColor('#5A574F')
              .backgroundColor('#E8E3D8')
              .borderRadius(12)
              .height(38)
              .enabled(!this.isLoading)
              .onClick(() => this.cancelSettings())
            Blank()
            Text('修改失败不会影响当前配置')
              .fontSize(11)
              .fontColor('#858178')
          }
          .width('100%')
        }

        Row() {
          Column({ space: 5 }) {
            Text('拾光 · MODEL GATE')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#A65B24')
              .letterSpacing(1.4)
            Text(this.currentPage === AppPage.SETTINGS ? '重新校准你的视觉模型' : '先让拾光学会看见')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#20201D')
            Text('一次小型视觉挑战，通过后才会安全保存配置。')
              .fontSize(14)
              .fontColor('#73716A')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text('01')
            .fontSize(44)
            .fontWeight(FontWeight.Bold)
            .fontColor('#DED7C8')
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        if (this.recoveryRequired) {
          Row({ space: 12 }) {
            Text('↻')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFDF8')
              .width(36)
              .height(36)
              .textAlign(TextAlign.Center)
              .backgroundColor('#A65B24')
              .borderRadius(18)
            Column({ space: 4 }) {
              Text('需要重新建立模型连接')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#5E351F')
              Text('已保存配置无法完整读取或解密。为保护凭证，拾光不会尝试继续使用它；请重新填写三项配置并通过视觉验证。')
                .fontSize(13)
                .fontColor('#79513B')
                .lineHeight(20)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding(16)
          .backgroundColor('#FFF4E8')
          .border({ width: 1, color: '#E6BD98' })
          .borderRadius(18)
        }

        Column({ space: 14 }) {
          this.SectionHeading('QUICK START', '选择服务端点', '模板只填写地址，不会修改或锁定模型。')
          this.EndpointButtons(MULTIMODAL_ENDPOINTS)

          Button(this.advancedExpanded ? '收起编程套餐端点  ↑' : '高级 · 编程套餐端点  ↓')
            .fontSize(13)
            .fontColor('#4E4B43')
            .backgroundColor(Color.Transparent)
            .padding(0)
            .onClick(() => this.advancedExpanded = !this.advancedExpanded)

          if (this.advancedExpanded) {
            Column({ space: 11 }) {
              Text('须确认厂商条款允许本应用调用')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#814C27')
                .width('100%')
                .padding(12)
                .backgroundColor('#FFF4E8')
                .borderRadius(12)
              this.EndpointButtons(CODING_ENDPOINTS)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .backgroundColor('#FFFDF8')
        .border({ width: 1, color: '#E8E2D5' })
        .borderRadius(22)

        Column({ space: 14 }) {
          this.SectionHeading('CONNECTION', '填写三项配置', '地址、凭证与模型必须齐全；模型建议始终可编辑。')

          this.FieldLabel('Base URL', '始终可编辑')
          TextInput({ placeholder: 'https://api.example.com/v1', text: this.baseURL })
            .type(InputType.Normal)
            .fontSize(14)
            .fontColor('#282721')
            .placeholderColor('#AAA69C')
            .height(50)
            .padding({ left: 14, right: 14 })
            .backgroundColor('#F5F2EA')
            .borderRadius(13)
            .onChange((value: string) => {
              const oldOrigin: string = parseOrigin(this.baseURL);
              this.baseURL = value;
              if (parseOrigin(value) !== oldOrigin) {
                this.resetOriginConfirmations();
              }
              this.clearError();
            })

          this.FieldLabel('API Key', this.hasSavedKey ? '留空则沿用已保存密钥' : '不会写入日志')
          TextInput({
            placeholder: this.hasSavedKey ? '已保存的密钥（不回显）' : '输入你的 API Key',
            text: this.apiKey
          })
            .type(InputType.Password)
            .fontSize(14)
            .fontColor('#282721')
            .placeholderColor('#AAA69C')
            .height(50)
            .padding({ left: 14, right: 14 })
            .backgroundColor('#F5F2EA')
            .borderRadius(13)
            .onChange((value: string) => {
              this.apiKey = value;
              this.clearError();
            })

          this.FieldLabel('Model ID', '可选择建议，也可自由输入')
          TextInput({ placeholder: '例如 gpt-4.1 或你的部署 ID', text: this.model })
            .type(InputType.Normal)
            .fontSize(14)
            .fontColor('#282721')
            .placeholderColor('#AAA69C')
            .height(50)
            .padding({ left: 14, right: 14 })
            .backgroundColor('#F5F2EA')
            .borderRadius(13)
            .onChange((value: string) => {
              this.model = value;
              this.clearError();
            })

          Scroll() {
            Row({ space: 8 }) {
              ForEach(RECOMMENDED_MODELS, (suggestion: ModelSuggestion) => {
                Button(suggestion.label)
                  .fontSize(12)
                  .fontColor(this.model === suggestion.model ? '#FFFDF8' : '#555148')
                  .backgroundColor(this.model === suggestion.model ? '#2C4438' : '#EEEAE0')
                  .borderRadius(11)
                  .height(34)
                  .onClick(() => {
                    this.model = suggestion.model;
                    this.clearError();
                  })
              }, (suggestion: ModelSuggestion) => suggestion.model)
            }
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .backgroundColor('#FFFDF8')
        .border({ width: 1, color: '#E8E2D5' })
        .borderRadius(22)

        if (this.isCustomSource()) {
          this.TrustNotice()
        }

        if (isLoopbackHttpOrigin(this.baseURL)) {
          this.LoopbackNotice()
        }

        if (this.errorMessage.length > 0) {
          this.ErrorPanel()
          if (this.currentPage === AppPage.SETTINGS) {
            Text('旧的已验证配置仍在安全使用；你可以修改草稿后重试，或取消返回时间轴。')
              .fontSize(12)
              .fontColor('#6F6B62')
              .lineHeight(18)
              .width('100%')
              .padding({ left: 4, right: 4 })
          }
        }

        if (this.verificationSucceeded) {
          this.SuccessPanel()
        }

        Button() {
          Row({ space: 10 }) {
            if (this.isLoading) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color('#FFFDF8')
              Text('正在进行视觉挑战…')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFDF8')
            } else {
              Text('验证视觉能力并保存')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFDF8')
              Text('→')
                .fontSize(19)
                .fontColor('#E7C391')
            }
          }
        }
        .width('100%')
        .height(56)
        .backgroundColor(this.isFormReady() ? '#2C4438' : '#B9B5AA')
        .borderRadius(16)
        .enabled(this.isFormReady())
        .onClick(() => this.startVerification())

        Text('凭证仅在验证与模型调用期间短暂解密；保存时由 HUKS 加密保护。')
          .fontSize(11)
          .fontColor('#8D8A82')
          .textAlign(TextAlign.Center)
          .lineHeight(17)
          .width('100%')
          .padding({ bottom: 20 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 28 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#F2EFE7')
  }

  @Builder
  private LoadingPage() {
    Column({ space: 20 }) {
      Stack() {
        Circle()
          .width(72)
          .height(72)
          .fill('#E5DDD0')
        Text('拾')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2C4438')
      }
      LoadingProgress()
        .width(28)
        .height(28)
        .color('#A65B24')
      Column({ space: 6 }) {
        Text('正在打开你的时间轴')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#282721')
        Text('安全检查已验证的模型配置…')
          .fontSize(13)
          .fontColor('#817D74')
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F2EFE7')
  }

  @Builder
  private TimelinePage() {
    Column() {
      Scroll() {
        Column({ space: 20 }) {
          Row() {
            Column({ space: 4 }) {
              Text('拾光 · TIMELINE')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#A65B24')
                .letterSpacing(1.4)
              Text('你的时间轴')
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor('#20201D')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Button('模型设置  ···')
              .fontSize(13)
              .fontColor('#FFFDF8')
              .backgroundColor('#2C4438')
              .borderRadius(14)
              .height(42)
              .onClick(() => this.openSettings())
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Column({ space: 14 }) {
            Row() {
              Column({ space: 5 }) {
                Text('MANUAL INGEST · 02')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#A65B24')
                  .letterSpacing(1.1)
                Text('导入一张截图')
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#292823')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              if (this.activeModel.length > 0) {
                Text(this.activeModel)
                  .fontSize(10)
                  .fontColor('#5C655E')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor('#E8EFE9')
                  .borderRadius(9)
              }
            }
            .width('100%')

            Text('先在设备端识别文字。首次发送到当前模型服务前，拾光会说明数据范围并征求确认。')
              .fontSize(13)
              .fontColor('#77736A')
              .lineHeight(20)
              .width('100%')

            Button() {
              Row({ space: 10 }) {
                if (this.isImporting) {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .color('#FFFDF8')
                  Text('正在处理截图…')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFDF8')
                } else {
                  Text('＋')
                    .fontSize(19)
                    .fontColor('#E7C391')
                  Text('从相册选择截图')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFDF8')
                }
              }
            }
            .width('100%')
            .height(52)
            .enabled(!this.isImporting)
            .backgroundColor(this.isImporting ? '#8F9A93' : '#2C4438')
            .borderRadius(15)
            .onClick(() => this.requestScreenshotImport())

            if (this.importStatus.length > 0) {
              Text(this.importStatus)
                .fontSize(12)
                .fontColor(this.ocrNeedsRetry || this.understandingErrorCategory.length > 0 ? '#8A4A2B' : '#5E655F')
                .lineHeight(18)
                .width('100%')
                .padding(12)
                .backgroundColor(this.ocrNeedsRetry || this.understandingErrorCategory.length > 0 ? '#FFF1E7' : '#EEF3EF')
                .borderRadius(11)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .backgroundColor('#FFFDF8')
          .border({ width: 1, color: '#E8E2D5' })
          .borderRadius(20)

          if (this.importedImageUri.length > 0) {
            Column({ space: 13 }) {
              Row() {
                Text('最近一次处理结果')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#292823')
                Blank()
                Text(this.understandingType.length > 0 ? this.understandingType :
                  (this.understandingErrorCategory.length > 0 ? this.understandingErrorCategory :
                    (this.ocrNeedsRetry ? 'OCR 待重试' : 'OCR 完成')))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.ocrNeedsRetry || this.understandingErrorCategory.length > 0 ? '#8A4A2B' : '#2C6A4E')
              }
              .width('100%')
              Image(this.importedImageUri)
                .width('100%')
                .height(190)
                .objectFit(ImageFit.Contain)
                .backgroundColor('#F2EFE7')
                .borderRadius(14)
              Text(this.importedImageSummary)
                .fontSize(11)
                .fontColor('#8A867D')
              if (this.thumbnailUri.length > 0) {
                Column({ space: 8 }) {
                  Text('发送给模型的私有缩略图')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#5B5A53')
                  Image(this.thumbnailUri)
                    .width('100%')
                    .height(150)
                    .objectFit(ImageFit.Contain)
                    .backgroundColor('#F2EFE7')
                    .borderRadius(12)
                  Text(this.thumbnailSummary)
                    .fontSize(11)
                    .fontColor('#8A867D')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
              Text(this.ocrPreview.length > 0 ? this.ocrPreview : '未识别到文字。')
                .fontSize(13)
                .fontColor('#47453F')
                .lineHeight(20)
                .maxLines(12)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .padding(14)
                .backgroundColor('#F6F3EC')
                .borderRadius(12)
              if (this.understandingType.length > 0) {
                Column({ space: 8 }) {
                  Row() {
                    Text('结构化理解')
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#2C4438')
                    Blank()
                    Text(this.understandingParseStatus)
                      .fontSize(10)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.understandingParseStatus === ParseStatus.PARSED ? '#2C6A4E' : '#8A4A2B')
                  }
                  .width('100%')
                  Text(`类型：${this.understandingType}`)
                    .fontSize(13)
                    .fontColor('#47453F')
                  Text(`截图时间表达：${this.understandingTimeText.length > 0 ? this.understandingTimeText : '—'}`)
                    .fontSize(13)
                    .fontColor('#47453F')
                  Text(`事件时间：${this.understandingEventTime.length > 0 ? this.understandingEventTime : '—'}`)
                    .fontSize(13)
                    .fontColor('#47453F')
                  Text(`地点：${this.understandingLocation.length > 0 ? this.understandingLocation : '—'}`)
                    .fontSize(13)
                    .fontColor('#47453F')
                  Text(`码号：${this.understandingCode.length > 0 ? this.understandingCode : '—'}`)
                    .fontSize(13)
                    .fontColor('#47453F')
                  Text(`金额：${this.understandingAmount.length > 0 ? this.understandingAmount : '—'}`)
                    .fontSize(13)
                    .fontColor('#47453F')
                  Text(`建议动作：${this.understandingActions}`)
                    .fontSize(13)
                    .fontColor('#47453F')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(14)
                .backgroundColor('#EEF3EF')
                .borderRadius(12)
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(18)
            .backgroundColor('#FFFDF8')
            .border({ width: 1, color: '#E8E2D5' })
            .borderRadius(20)
          }

          Text('正式时间轴卡片将在 Task 2.3–2.5 接入；当前区域用于验证导入、端侧 OCR、缩略图与结构化理解。')
            .fontSize(11)
            .fontColor('#969187')
            .lineHeight(17)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ bottom: 18 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 30 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Row() {
        Column({ space: 5 }) {
          Text('●')
            .fontSize(16)
            .fontColor('#A65B24')
          Text('时间轴')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3B3933')
        }
        .layoutWeight(1)
        Column({ space: 5 }) {
          Text('◇')
            .fontSize(18)
            .fontColor('#AAA69C')
          Text('搜索 · 后续')
            .fontSize(11)
            .fontColor('#99958C')
        }
        .layoutWeight(1)
        Column({ space: 5 }) {
          Text('○')
            .fontSize(18)
            .fontColor('#AAA69C')
          Text('收藏 · 后续')
            .fontSize(11)
            .fontColor('#99958C')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height(76)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 14 })
      .backgroundColor('#FFFDF8')
      .border({ width: { top: 1 }, color: '#E2DBCE' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2EFE7')
  }

  build() {
    if (this.currentPage === AppPage.LOADING) {
      this.LoadingPage()
    } else if (this.currentPage === AppPage.HOME) {
      this.TimelinePage()
    } else {
      this.WizardPage()
    }
  }
}
