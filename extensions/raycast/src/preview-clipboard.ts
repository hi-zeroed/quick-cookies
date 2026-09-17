import { closeMainWindow, open, showHUD, showToast, Toast } from "@raycast/api";

export default async function Command() {
  try {
    await closeMainWindow();
    await open("quickcookies://preview?source=clipboard");
    await showHUD("QuickCookies: Inspecting clipboard content");
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Failed to inspect clipboard",
      message: String(error),
    });
  }
}
