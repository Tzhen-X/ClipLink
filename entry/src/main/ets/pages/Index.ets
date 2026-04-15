import HomePage from './HomePage';
import HistoryPage from './HistoryPage';
import SettingsPage from './SettingsPage';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { ThemeUtil, ThemePalette } from '../utils/ThemeUtil';
import { getBottomTabLayoutSpec, getMainTabSpecs, MainTabSpec } from '../utils/PageScaffoldUtil';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  private readonly tabs: MainTabSpec[] = getMainTabSpecs();
  private readonly tabLayout = getBottomTabLayoutSpec();

  private getPalette(): ThemePalette {
    return ThemeUtil.getPalette(this.appTheme, this.systemColorMode);
  }

  private getTabIcon(key: string): Resource {
    switch (key) {
      case 'history':
        return $r('sys.symbol.clock_fill');
      case 'settings':
        return $r('sys.symbol.gearshape_fill');
      default:
        return $r('sys.symbol.house_fill');
    }
  }

  @Builder TabBuilder(tab: MainTabSpec, targetIndex: number) {
    Column() {
      SymbolGlyph(this.getTabIcon(tab.key))
        .fontSize(this.tabLayout.iconSize)
        .fontColor([
          this.currentTabIndex === targetIndex
            ? this.getPalette().accent
            : this.getPalette().textSecondary
        ])
        .fontWeight(FontWeight.Medium)
      Text(tab.label)
        .margin({ top: this.tabLayout.labelTopMargin })
        .fontSize($r('sys.float.Caption_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor(
          this.currentTabIndex === targetIndex
            ? this.getPalette().accent
            : this.getPalette().textSecondary
        )
    }
    .width('100%')
    .height(this.tabLayout.itemHeight)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.Transparent)
  }

  build() {
    Tabs({ index: this.currentTabIndex }) {
      ForEach(this.tabs, (tab: MainTabSpec, index: number) => {
        TabContent() {
          if (tab.key === 'home') {
            HomePage()
          } else if (tab.key === 'history') {
            HistoryPage()
          } else {
            SettingsPage()
          }
        }
        .tabBar(this.TabBuilder(tab, index))
      }, (tab: MainTabSpec) => tab.key)
    }
    .width('100%')
    .height('100%')
    .barPosition(BarPosition.End)
    .barHeight(this.tabLayout.barHeight)
    .backgroundColor(this.getPalette().pageBackground)
    .barBackgroundColor(this.getPalette().pageSurface)
    .backgroundBlurStyle(BlurStyle.NONE)
    .barMode(BarMode.Fixed)
    .scrollable(false)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    })
  }
}
