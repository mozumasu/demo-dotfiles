import { Clipboard, showHUD } from "@raycast/api";
import { currentTabUrl } from "./ardia";

export default async function Command() {
  try {
    const url = await currentTabUrl();
    if (!url) {
      await showHUD("No tab in Ardia");
      return;
    }
    await Clipboard.copy(url);
    await showHUD(`Copied ${url}`);
  } catch (e) {
    await showHUD(`Failed to copy URL: ${e}`);
  }
}
