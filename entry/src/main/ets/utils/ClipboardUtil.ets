import pasteboard from '@ohos.pasteboard';

/**
 * Clipboard utility - read/write clipboard text
 */
export class ClipboardUtil {
  /**
   * Read text from system clipboard
   */
  static async getClipboardText(): Promise<string> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      if (!(await systemPasteboard.hasData())) {
        return '';
      }

      const pasteData = await systemPasteboard.getData();
      const text = pasteData.getPrimaryText();
      
      return text || '';
    } catch (error) {
      console.error('[ClipboardUtil] getClipboardText error:', JSON.stringify(error));
      return '';
    }
  }

  /**
   * Write text to system clipboard
   */
  static async setClipboardText(text: string): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await systemPasteboard.setData(pasteData);
    } catch (error) {
      console.error('[ClipboardUtil] setClipboardText error:', JSON.stringify(error));
      throw new Error('Failed to set clipboard text');
    }
  }

  /**
   * Check if clipboard has text data
   */
  static async hasText(): Promise<boolean> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      return await systemPasteboard.hasData();
    } catch (error) {
      console.error('[ClipboardUtil] hasText error:', JSON.stringify(error));
      return false;
    }
  }
}
