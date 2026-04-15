import HomePage from './HomePage';
import HistoryPage from './HistoryPage';
import SettingsPage from './SettingsPage';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { ThemeUtil, ThemePalette } from '../utils/ThemeUtil';
import {
  getBottomTabLayoutSpec,
  getMainTabSpecs,
  getSystemSafeAreaInsets,
  MainTabSpec
} from '../utils/PageScaffoldUtil';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  @StorageLink('appTheme') appTheme: string = 'auto';
  @StorageLink('preferPureBlackInDark') preferPureBlackInDark: boolean = false;
  @StorageLink('safeAreaTop') safeAreaTop: number = 44;
  @StorageLink('safeAreaBottom') safeAreaBottom: number = 0;
  @StorageLink('systemColorMode') systemColorMode: number =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  private readonly tabs: MainTabSpec[] = getMainTabSpecs();
  private readonly tabLayout = getBottomTabLayoutSpec();

  private getPalette(): ThemePalette {
    return ThemeUtil.getPalette(
      this.appTheme as 'light' | 'dark' | 'auto',
      this.systemColorMode,
      this.preferPureBlackInDark
    );
  }

  private getSafeAreaInsets() {
    return getSystemSafeAreaInsets(this.safeAreaTop, this.safeAreaBottom);
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
    .padding({ top: 6, bottom: 6 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.Transparent)
  }

  build() {
    Stack() {
      Column() {
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
            .clip(false)
          }, (tab: MainTabSpec) => tab.key)
        }
        .width('100%')
        .layoutWeight(1)
        .barPosition(BarPosition.End)
        .barHeight(this.tabLayout.barHeight)
        .barBackgroundColor(this.getPalette().pageSurface)
        .backgroundBlurStyle(BlurStyle.NONE)
        .barMode(BarMode.Fixed)
        .scrollable(false)
        .clip(false)
        .onChange((index: number) => {
          this.currentTabIndex = index;
        })
      }
      .width('100%')
      .height('100%')
      .padding({
        top: this.getSafeAreaInsets().top,
        bottom: this.getSafeAreaInsets().bottom
      })
      .backgroundColor(this.getPalette().pageBackground)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageSurface)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
