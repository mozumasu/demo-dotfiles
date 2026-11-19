import { closeMainWindow, showHUD } from "@raycast/api";
import { newWindow } from "./ardia";

export default async function Command() {
  try {
    await closeMainWindow();
    await newWindow(false);
  } catch (e) {
    await showHUD(`Failed to open window: ${e}`);
  }
}
