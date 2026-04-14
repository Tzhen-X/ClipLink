import HomePage from './HomePage';
import HistoryPage from './HistoryPage';
import SettingsPage from './SettingsPage';
import { ConfigurationConstant } from '@kit.AbilityKit';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

  private isDarkTheme(): boolean {
    return (
      this.appTheme === 'dark' ||
      (this.appTheme === 'auto' &&
        this.systemColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
    );
  }

  @Builder TabBuilder(title: string, targetIndex: number) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(this.currentTabIndex === targetIndex ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTabIndex === targetIndex ? '#007DFF' : this.isDarkTheme() ? '#CFCFCF' : '#666666')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
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
    .backgroundColor(this.isDarkTheme() ? '#111111' : '#F5F5F5')
    .onChange((index: number) => {
      this.currentTabIndex = index;
    })
  }
}
