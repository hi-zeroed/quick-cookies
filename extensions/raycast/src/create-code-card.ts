import { closeMainWindow, getSelectedFinderItems, open, showHUD, showToast, Toast } from "@raycast/api";

export default async function Command() {
  try {
    await closeMainWindow();

    // 1. 尝试查看是否有 Finder 选中项
    let selectedItems: { path: string }[] = [];
    try {
      selectedItems = await getSelectedFinderItems();
    } catch {
      // 忽略
    }

    if (selectedItems.length > 0 && selectedItems[0]?.path) {
      const filePath = selectedItems[0].path;
      const encodedPath = encodeURIComponent(filePath);
      await open(`quickcookies://preview?action=shareCard&path=${encodedPath}`);
      await showHUD(`QuickCookies: Generating card for ${selectedItems[0].path.split("/").pop() || "file"}`);
    } else {
      // 未选定文件时，直达卡片工坊（优先嗅探剪贴板中的代码）
      await open("quickcookies://preview?action=shareCard");
      await showHUD("QuickCookies: Opening Card Studio");
    }
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Failed to open Card Studio",
      message: String(error),
    });
  }
}
