import { closeMainWindow, getSelectedFinderItems, open, showHUD, showToast, Toast } from "@raycast/api";

export default async function Command() {
  try {
    await closeMainWindow();
    
    // 1. 尝试获取当前 Finder 选中的文件列表
    let selectedItems: { path: string }[] = [];
    try {
      selectedItems = await getSelectedFinderItems();
    } catch {
      // 当前未处于 Finder，或没有可访问的选中项
    }

    if (selectedItems.length > 0 && selectedItems[0]?.path) {
      const filePath = selectedItems[0].path;
      const encodedPath = encodeURIComponent(filePath);
      await open(`quickcookies://preview?path=${encodedPath}`);
      await showHUD(`QuickCookies: Previewing ${selectedItems[0].path.split("/").pop() || "file"}`);
    } else {
      // 回退到 QuickCookies 原生访达探测器
      await open("quickcookies://preview?action=finderSelection");
      await showHUD("QuickCookies: Previewing selected file");
    }
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Failed to preview file",
      message: String(error),
    });
  }
}
