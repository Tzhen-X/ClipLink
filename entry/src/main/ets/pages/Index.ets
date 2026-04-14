import HomePage from './HomePage';
import HistoryPage from './HistoryPage';
import SettingsPage from './SettingsPage';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { ThemeUtil, ThemePalette } from '../utils/ThemeUtil';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

  private getPalette(): ThemePalette {
    return ThemeUtil.getPalette(this.appTheme, this.systemColorMode);
  }

  @Builder TabBuilder(title: string, targetIndex: number) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(this.currentTabIndex === targetIndex ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(
          this.currentTabIndex === targetIndex
            ? this.getPalette().accent
            : this.getPalette().textSecondary
        )
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.currentTabIndex === targetIndex ? this.getPalette().accentSoft : this.getPalette().cardBackground)
    .borderRadius(16)
  }

  build() {
    Tabs({ index: this.currentTabIndex }) {
      TabContent() {
        HomePage()
      }
      .tabBar(this.TabBuilder('Home', 0))

      TabContent() {
        HistoryPage()
      }
      .tabBar(this.TabBuilder('History', 1))

      TabContent() {
        SettingsPage()
      }
      .tabBar(this.TabBuilder('Settings', 2))
    }
    .width('100%')
    .height('100%')
    .barPosition(BarPosition.End)
    .backgroundColor(this.getPalette().pageBackground)
    .barBackgroundColor(this.getPalette().cardBackground)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    })
  }
}
