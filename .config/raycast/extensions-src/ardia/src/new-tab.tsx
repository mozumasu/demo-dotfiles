import { closeMainWindow, LaunchProps, showHUD } from "@raycast/api";
import { openInNewTab, toUrl } from "./ardia";

export default async function Command(props: LaunchProps<{ arguments: Arguments.NewTab }>) {
  const query = props.arguments.query?.trim();
  try {
    await closeMainWindow();
    await openInNewTab(query ? toUrl(query) : undefined);
  } catch (e) {
    await showHUD(`Failed to open tab: ${e}`);
  }
}
