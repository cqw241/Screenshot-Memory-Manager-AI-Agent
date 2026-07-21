@Entry
@Component
struct Index {
  build() {
    Column({ space: 18 }) {
      Text('拾光')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor('#24243A')

      Text('让截图在合适的时刻重新开口')
        .fontSize(17)
        .fontColor('#6B6B80')

      Text('Story 1 工程入口已就绪')
        .fontSize(14)
        .fontColor('#5B5BD6')
        .padding({ top: 24 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(32)
    .backgroundColor('#F7F7FC')
  }
}

