import { ConfigurationConstant } from '@kit.AbilityKit';
import { describe, it, expect } from '@ohos/hypium';
import {
  getActionButtonSpec,
  getAutoSyncIndicatorSpec,
  getBottomTabLayoutSpec,
  getCardEffectMode,
  getClipboardPreviewMode,
  getHistoryActionFeedback,
  getHistoryListStyleSpec,
  getMainTabSpecs,
  getResolvedThemeVariant,
  getSystemSafeAreaInsets,
  getSettingsSectionSpecs,
  getWindowChromeSpec,
  getSyncStatusTone
} from '../main/ets/utils/PageScaffoldUtil';

export default function testsuite() {
  describe('PageScaffoldUtil', () => {
    it('returns the three main tabs in app order', 0, () => {
      const tabs = getMainTabSpecs();
      expect(tabs.length).assertEqual(3);
      expect(tabs[0].label).assertEqual('Home');
      expect(tabs[1].label).assertEqual('History');
      expect(tabs[2].label).assertEqual('Settings');
    });

    it('maps sync status text into a visual tone', 0, () => {
      expect(getSyncStatusTone('Upload Success')).assertEqual('success');
      expect(getSyncStatusTone('Download Error: offline')).assertEqual('danger');
      expect(getSyncStatusTone('Idle')).assertEqual('neutral');
    });

    it('defines the settings page as two grouped sections', 0, () => {
      const sections = getSettingsSectionSpecs();
      expect(sections.length).assertEqual(2);
      expect(sections[0].title).assertEqual('Server Connection');
      expect(sections[1].rowCount).assertEqual(4);
    });

    it('keeps the bottom tabs lightweight like the official demo', 0, () => {
      const layout = getBottomTabLayoutSpec();
      expect(layout.barHeight).assertEqual(50);
      expect(layout.itemHeight).assertEqual(0);
      expect(layout.usesSelectedBackground).assertEqual(false);
      expect(layout.usesSystemSafeAreaExpansion).assertEqual(false);
      expect(layout.usesExternalBottomBar).assertEqual(false);
      expect(layout.safeAreaFollowsBarSurface).assertEqual(true);
      expect(layout.rootOwnsBottomSafeArea).assertEqual(true);
      expect(layout.isFloating).assertEqual(true);
    });

    it('switches current clipboard into image preview mode when summary indicates an image', 0, () => {
      expect(getClipboardPreviewMode('[Image in clipboard]')).assertEqual('image');
      expect(getClipboardPreviewMode('hello world')).assertEqual('text');
    });

    it('keeps history list styling simple and without helper copy', 0, () => {
      const style = getHistoryListStyleSpec();
      expect(style.usesSubtitle).assertEqual(false);
      expect(style.usesDivider).assertEqual(false);
      expect(style.metaLines).assertEqual(1);
    });

    it('describes auto sync state with style instead of button copy', 0, () => {
      const activeSpec = getAutoSyncIndicatorSpec(true);
      const inactiveSpec = getAutoSyncIndicatorSpec(false);
      expect(activeSpec.label).assertEqual('Auto Sync');
      expect(activeSpec.tone).assertEqual('success');
      expect(inactiveSpec.tone).assertEqual('neutral');
    });

    it('uses compact action buttons for home and settings', 0, () => {
      const homeAction = getActionButtonSpec('home-primary');
      const settingsAction = getActionButtonSpec('settings-save');
      expect(homeAction.controlSize).assertEqual('small');
      expect(settingsAction.fullWidth).assertEqual(false);
    });

    it('turns off card glow in dark mode', 0, () => {
      expect(getCardEffectMode(true)).assertEqual('none');
      expect(getCardEffectMode(false)).assertEqual('subtle');
    });

    it('keeps history list tighter and removes copy affordance text', 0, () => {
      const style = getHistoryListStyleSpec();
      expect(style.showsCopyLabel).assertEqual(false);
      expect(style.sideInset).assertEqual(0);
    });

    it('uses toast feedback for history actions', 0, () => {
      const copyOk = getHistoryActionFeedback('copy-text', true);
      const saveFail = getHistoryActionFeedback('save-image', false);
      expect(copyOk.mode).assertEqual('toast');
      expect(copyOk.message).assertEqual('Copied to clipboard');
      expect(saveFail.message).assertEqual('Image download failed');
    });

    it('remembers whether dark appearance should use pure black', 0, () => {
      const darkMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      const lightMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

      expect(getResolvedThemeVariant('dark', lightMode, false)).assertEqual('dark');
      expect(getResolvedThemeVariant('dark', lightMode, true)).assertEqual('black');
      expect(getResolvedThemeVariant('auto', darkMode, false)).assertEqual('dark');
      expect(getResolvedThemeVariant('auto', darkMode, true)).assertEqual('black');
      expect(getResolvedThemeVariant('auto', lightMode, true)).assertEqual('light');
    });

    it('keeps top content and bottom tabs inside system safe areas', 0, () => {
      const insets = getSystemSafeAreaInsets(24, 18);
      const emptyInsets = getSystemSafeAreaInsets(-1, -5);

      expect(insets.top).assertEqual(24);
      expect(insets.bottom).assertEqual(18);
      expect(emptyInsets.top).assertEqual(0);
      expect(emptyInsets.bottom).assertEqual(0);
    });

    it('uses system-managed window chrome instead of fullscreen transparent bars', 0, () => {
      const chrome = getWindowChromeSpec();
      expect(chrome.usesFullscreenLayout).assertEqual(false);
      expect(chrome.usesTransparentSystemBars).assertEqual(false);
      expect(chrome.managesNavigationBar).assertEqual(false);
    });
  });
}
