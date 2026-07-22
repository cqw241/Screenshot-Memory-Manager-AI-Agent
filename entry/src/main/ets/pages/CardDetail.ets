import { common } from '@kit.AbilityKit';
import {
  CardStorageError,
  ScreenshotCard,
  ScreenshotCardRepositoryPort
} from '../models/ScreenshotCardModels';
import {
  CardBadgeTone,
  formatCardBadgeTone,
  formatCreatedAt,
  formatParseStatus,
  formatScreenshotTitle,
  formatScreenshotTypeLabel,
  formatSuggestedActions
} from '../models/ScreenshotCardPresentation';
import { createScreenshotCardRepository } from '../services/ScreenshotCardRepositoryFactory';

interface CardDetailRouteParams {
  cardId?: string;
}

enum CardDetailState {
  LOADING = 'LOADING',
  READY = 'READY',
  ERROR = 'ERROR'
}

@Entry
@Component
struct CardDetail {
  @State private state: CardDetailState = CardDetailState.LOADING;
  @State private card: ScreenshotCard | undefined = undefined;
  @State private errorCategory: string = '';
  @State private errorMessage: string = '';
  @State private retryAvailable: boolean = false;
  @State private isDeleting: boolean = false;
  @State private deleteErrorMessage: string = '';

  private repository?: ScreenshotCardRepositoryPort;
  private cardId: string = '';

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showError('无法打开卡片', '当前页面上下文暂时不可用。', false);
      return;
    }
    this.repository = createScreenshotCardRepository(context);
    this.resolveRouteAndLoad();
  }

  private async resolveRouteAndLoad(): Promise<void> {
    const params: CardDetailRouteParams =
      this.getUIContext().getRouter().getParams() as CardDetailRouteParams;
    if (typeof params.cardId !== 'string' || params.cardId.trim().length === 0) {
      this.showError('无法打开卡片', '详情入口缺少有效的卡片标识。', false);
      return;
    }
    this.cardId = params.cardId;
    await this.loadCard();
  }

  private async loadCard(): Promise<void> {
    if (this.repository === undefined || this.cardId.length === 0) {
      this.showError('无法打开卡片', '本地卡片服务暂时不可用。', false);
      return;
    }
    this.state = CardDetailState.LOADING;
    this.errorCategory = '';
    this.errorMessage = '';
    this.retryAvailable = false;
    try {
      const card: ScreenshotCard | undefined = await this.repository.getById(this.cardId);
      if (card === undefined) {
        this.card = undefined;
        this.showError('卡片不存在', '这张卡片可能已被删除。', false);
        return;
      }
      this.card = card;
      this.state = CardDetailState.READY;
    } catch (error) {
      this.card = undefined;
      if (error instanceof CardStorageError) {
        this.showError(error.category, error.userMessage, true);
      } else {
        this.showError('卡片读取失败', '暂时无法读取这张本地卡片。', true);
      }
    }
  }

  private showError(category: string, message: string, retryAvailable: boolean): void {
    this.errorCategory = category;
    this.errorMessage = message;
    this.retryAvailable = retryAvailable;
    this.state = CardDetailState.ERROR;
  }

  private goBack(): void {
    this.getUIContext().getRouter().back();
  }

  private confirmDelete(): void {
    if (this.isDeleting || this.card === undefined) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除这张卡片？',
      message: '只会删除拾光中的卡片记录，不影响相册原图。应用私有原图与缩略图也会保留。',
      primaryButton: {
        value: '确认删除',
        fontColor: '#A84832',
        action: () => {
          this.deleteCard();
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: '#68635A',
        action: () => {
        }
      }
    });
  }

  private async deleteCard(): Promise<void> {
    if (this.repository === undefined || this.cardId.length === 0 || this.isDeleting) {
      return;
    }
    this.isDeleting = true;
    this.deleteErrorMessage = '';
    try {
      const deleted: boolean = await this.repository.deleteById(this.cardId);
      if (deleted) {
        this.goBack();
        return;
      }
      this.card = undefined;
      this.showError('卡片不存在', '这张卡片已经不在时间轴中。', false);
    } catch (error) {
      if (error instanceof CardStorageError) {
        this.deleteErrorMessage = `${error.category}：${error.userMessage}`;
      } else {
        this.deleteErrorMessage = '卡片删除失败：卡片未能删除，请稍后重试。';
      }
    } finally {
      this.isDeleting = false;
    }
  }

  private displayValue(value: string | null): string {
    return value === null || value.length === 0 ? '—' : value;
  }

  private badgeBackgroundColor(tone: CardBadgeTone): string {
    if (tone === CardBadgeTone.FOREST) {
      return '#E3EEE7';
    }
    if (tone === CardBadgeTone.CLAY) {
      return '#F7E6D8';
    }
    if (tone === CardBadgeTone.AMBER) {
      return '#F6EDCF';
    }
    return '#ECE9E2';
  }

  private badgeTextColor(tone: CardBadgeTone): string {
    if (tone === CardBadgeTone.FOREST) {
      return '#2C6A4E';
    }
    if (tone === CardBadgeTone.CLAY) {
      return '#9A542A';
    }
    if (tone === CardBadgeTone.AMBER) {
      return '#8A671C';
    }
    return '#6F6B62';
  }

  @Builder
  private DetailField(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .width(82)
        .fontSize(12)
        .fontColor('#918C82')
      Text(value)
        .layoutWeight(1)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3F3D37')
        .lineHeight(19)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  @Builder
  private LoadingState() {
    Column({ space: 14 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .color('#A65B24')
      Text('正在打开这段记忆')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3F3D37')
      Text('从本地安全存储读取卡片…')
        .fontSize(12)
        .fontColor('#8A867D')
    }
    .width('100%')
    .padding({ top: 110, bottom: 110 })
  }

  @Builder
  private ErrorState() {
    Column({ space: 13 }) {
      Text('!')
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFDF8')
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor('#A84832')
        .borderRadius(22)
      Text(this.errorCategory)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#68372C')
      Text(this.errorMessage)
        .fontSize(13)
        .fontColor('#7A4A3E')
        .lineHeight(20)
        .textAlign(TextAlign.Center)
      if (this.retryAvailable) {
        Button('重新读取')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFDF8')
          .height(40)
          .backgroundColor('#7A493C')
          .borderRadius(12)
          .onClick(() => this.loadCard())
      }
      Button('返回时间轴')
        .fontSize(13)
        .fontColor('#5F5A51')
        .height(40)
        .backgroundColor('#E8E1D5')
        .borderRadius(12)
        .onClick(() => this.goBack())
    }
    .width('100%')
    .padding({ top: 42, bottom: 42, left: 24, right: 24 })
    .backgroundColor('#FFF0EC')
    .border({ width: 1, color: '#E8C4BA' })
    .borderRadius(22)
  }

  @Builder
  private CardContent(card: ScreenshotCard) {
    Column({ space: 16 }) {
      Stack() {
        Column({ space: 6 }) {
          Text('拾')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B5A58F')
          Text('原图暂时无法显示')
            .fontSize(11)
            .fontColor('#918C82')
        }
        Image(card.imageUri)
          .width('100%')
          .height(286)
          .objectFit(ImageFit.Contain)
          .borderRadius(18)
      }
      .width('100%')
      .height(286)
      .backgroundColor('#E8E1D5')
      .borderRadius(18)
      .clip(true)

      Column({ space: 8 }) {
        Row() {
          Text(formatScreenshotTypeLabel(card.type))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.badgeTextColor(formatCardBadgeTone(card.type)))
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor(this.badgeBackgroundColor(formatCardBadgeTone(card.type)))
            .borderRadius(8)
          Blank()
          Text(formatParseStatus(card.parseStatus))
            .fontSize(10)
            .fontColor('#8A867D')
        }
        .width('100%')
        Text(formatScreenshotTitle(card.type))
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor('#292823')
        Text(`${formatCreatedAt(card.createdAt)} 导入`)
          .fontSize(11)
          .fontColor('#8A867D')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor('#FFFDF8')
      .border({ width: 1, color: '#E8E2D5' })
      .borderRadius(18)

      Column() {
        this.DetailField('时间表达', this.displayValue(card.entities.timeText))
        Divider().color('#EEE9DF').margin({ left: 14, right: 14 })
        this.DetailField('事件时间', this.displayValue(card.entities.eventTime))
        Divider().color('#EEE9DF').margin({ left: 14, right: 14 })
        this.DetailField('地点', this.displayValue(card.entities.location))
        Divider().color('#EEE9DF').margin({ left: 14, right: 14 })
        this.DetailField('码号', this.displayValue(card.entities.code))
        Divider().color('#EEE9DF').margin({ left: 14, right: 14 })
        this.DetailField('金额', this.displayValue(card.entities.amount))
        Divider().color('#EEE9DF').margin({ left: 14, right: 14 })
        this.DetailField('建议动作', card.actions.length === 0 ? '—' : formatSuggestedActions(card.actions))
        Divider().color('#EEE9DF').margin({ left: 14, right: 14 })
        this.DetailField('解析状态', formatParseStatus(card.parseStatus))
      }
      .width('100%')
      .backgroundColor('#FFFDF8')
      .border({ width: 1, color: '#E8E2D5' })
      .borderRadius(18)

      Column({ space: 8 }) {
        if (this.deleteErrorMessage.length > 0) {
          Text(this.deleteErrorMessage)
            .fontSize(12)
            .fontColor('#8A4A2B')
            .lineHeight(18)
            .width('100%')
            .padding(11)
            .backgroundColor('#FFF0EC')
            .borderRadius(11)
        }
        Button(this.isDeleting ? '正在删除…' : '删除这张卡片')
          .width('100%')
          .height(46)
          .enabled(!this.isDeleting)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#9A4433')
          .backgroundColor('#FFF8F5')
          .border({ width: 1, color: '#D8A091' })
          .borderRadius(14)
          .onClick(() => this.confirmDelete())
        Text('删除只影响拾光卡片记录，不会移除任何图片文件。')
          .fontSize(10)
          .fontColor('#999187')
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
      .padding({ bottom: 18 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('←  返回')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#555148')
          .height(38)
          .backgroundColor('#E6DED1')
          .borderRadius(12)
          .onClick(() => this.goBack())
        Blank()
        Column({ space: 3 }) {
          Text('MEMORY DETAIL')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor('#A65B24')
            .letterSpacing(1.1)
          Text('记忆详情')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#292823')
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .height(72)
      .padding({ left: 18, right: 18 })
      .backgroundColor('#FFFDF8')
      .border({ width: { bottom: 1 }, color: '#E2DBCE' })

      Scroll() {
        Column() {
          if (this.state === CardDetailState.LOADING) {
            this.LoadingState()
          } else if (this.state === CardDetailState.ERROR || this.card === undefined) {
            this.ErrorState()
          } else {
            this.CardContent(this.card)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2EFE7')
  }
}
