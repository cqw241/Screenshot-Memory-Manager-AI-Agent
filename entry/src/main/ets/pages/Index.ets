import { common } from '@kit.AbilityKit';
import { createConfigRepository } from '../services/ConfigRepositoryFactory';

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    createConfigRepository(context).getState().catch((_error: Error) => {
      // 启动路由与可恢复错误提示在 Task 1.5 接入。
    });
  }

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
