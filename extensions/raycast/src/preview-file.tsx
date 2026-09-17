import React, { useState, useEffect } from "react";
import { ActionPanel, Action, List, Icon, open, closeMainWindow, showHUD } from "@raycast/api";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

interface FileEntry {
  name: string;
  path: string;
  isDirectory: boolean;
  size?: number;
}

export default function Command() {
  const [searchText, setSearchText] = useState("");
  const [currentDir, setCurrentDir] = useState(os.homedir());
  const [entries, setEntries] = useState<FileEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // 加载当前目录的文件
  useEffect(() => {
    try {
      setIsLoading(true);
      const targetDir = searchText.startsWith("/") && fs.existsSync(searchText) && fs.statSync(searchText).isDirectory()
        ? searchText
        : currentDir;

      if (fs.existsSync(targetDir)) {
        const files = fs.readdirSync(targetDir);
        const list: FileEntry[] = [];
        for (const file of files) {
          if (file.startsWith(".")) continue; // 忽略隐藏文件
          const fullPath = path.join(targetDir, file);
          try {
            const stat = fs.statSync(fullPath);
            list.push({
              name: file,
              path: fullPath,
              isDirectory: stat.isDirectory(),
              size: stat.size,
            });
          } catch {
            // 忽略无权限或已失效文件
          }
        }
        setEntries(list.sort((a, b) => (b.isDirectory ? 1 : 0) - (a.isDirectory ? 1 : 0) || a.name.localeCompare(b.name)));
      }
    } catch {
      setEntries([]);
    } finally {
      setIsLoading(false);
    }
  }, [currentDir, searchText]);

  const handlePreview = async (filePath: string) => {
    await closeMainWindow();
    const encoded = encodeURIComponent(filePath);
    await open(`quickcookies://preview?path=${encoded}`);
    await showHUD(`QuickCookies: Previewing ${path.basename(filePath)}`);
  };

  const handleMakeCard = async (filePath: string) => {
    await closeMainWindow();
    const encoded = encodeURIComponent(filePath);
    await open(`quickcookies://preview?action=shareCard&path=${encoded}`);
    await showHUD(`QuickCookies: Card Studio for ${path.basename(filePath)}`);
  };

  const commonLocations: FileEntry[] = [
    { name: "Home (~)", path: os.homedir(), isDirectory: true },
    { name: "Desktop", path: path.join(os.homedir(), "Desktop"), isDirectory: true },
    { name: "Downloads", path: path.join(os.homedir(), "Downloads"), isDirectory: true },
    { name: "Documents", path: path.join(os.homedir(), "Documents"), isDirectory: true },
  ];

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder="Type path or file name (e.g. ~/Desktop or README.md)..."
      onSearchTextChange={setSearchText}
    >
      <List.Section title="Quick Locations">
        {commonLocations.map((loc) => (
          <List.Item
            key={loc.path}
            icon={Icon.Folder}
            title={loc.name}
            subtitle={loc.path}
            actions={
              <ActionPanel>
                <Action title="Open in QuickCookies" onAction={() => handlePreview(loc.path)} />
                <Action title="Browse Folder" onAction={() => setCurrentDir(loc.path)} />
                <Action.ShowInFinder path={loc.path} />
                <Action.CopyToClipboard content={loc.path} title="Copy Path" />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>

      <List.Section title={`Files in ${currentDir}`}>
        {entries.map((entry) => (
          <List.Item
            key={entry.path}
            icon={entry.isDirectory ? Icon.Folder : Icon.Document}
            title={entry.name}
            subtitle={entry.path}
            actions={
              <ActionPanel>
                <Action title="Preview in QuickCookies" onAction={() => handlePreview(entry.path)} />
                <Action
                  title="Create Code Card"
                  shortcut={{ modifiers: ["cmd"], key: "s" }}
                  onAction={() => handleMakeCard(entry.path)}
                />
                {entry.isDirectory && (
                  <Action title="Enter Directory" onAction={() => setCurrentDir(entry.path)} />
                )}
                <Action.ShowInFinder path={entry.path} />
                <Action.CopyToClipboard content={entry.path} title="Copy Path" />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
    </List>
  );
}
