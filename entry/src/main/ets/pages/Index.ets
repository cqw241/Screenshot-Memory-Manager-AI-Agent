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
import { VerifiedConfigMetadata } from '../models/ModelConfig';
import { ConfigRepository } from '../services/ConfigRepository';
import { createConfigRepository } from '../services/ConfigRepositoryFactory';

@Entry
@Component
struct Index {
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

  private repository?: ConfigRepository;

  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.repository = createConfigRepository(context);
    this.loadExistingConfiguration();
  }

  private async loadExistingConfiguration(): Promise<void> {
    if (this.repository === undefined) {
      return;
    }
    try {
      const metadata: VerifiedConfigMetadata | undefined = await this.repository.getMetadata();
      if (metadata !== undefined) {
        this.baseURL = metadata.baseURL;
        this.model = metadata.model;
        this.hasSavedKey = true;
        this.resetOriginConfirmations();
      }
    } catch (_error) {
      // 损坏配置的可恢复启动说明在 Task 1.5 统一处理。
    }
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
  }

  private isCustomSource(): boolean {
    return this.baseURL.trim().length > 0 && !isKnownOfficialOrigin(this.baseURL) && !isLoopbackHttpOrigin(this.baseURL);
  }

  private isFormReady(): boolean {
    const fieldsComplete: boolean = this.baseURL.trim().length > 0 &&
      (this.apiKey.length > 0 || this.hasSavedKey) && this.model.trim().length > 0;
    const trustReady: boolean = !this.isCustomSource() || this.customSourceTrusted;
    const loopbackReady: boolean = !isLoopbackHttpOrigin(this.baseURL) || this.loopbackWarningAccepted;
    return fieldsComplete && trustReady && loopbackReady && !this.isLoading;
  }

  private startVerification(): void {
    if (!this.isFormReady()) {
      return;
    }
    this.clearError();
    this.isLoading = true;
    // Task 1.4 接入视觉挑战、错误分类与事务式保存。
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

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Row() {
          Column({ space: 5 }) {
            Text('拾光 · MODEL GATE')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor('#A65B24')
              .letterSpacing(1.4)
            Text(this.hasSavedKey ? '重新校准你的视觉模型' : '先让拾光学会看见')
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
              this.baseURL = value;
              this.resetOriginConfirmations();
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
}
