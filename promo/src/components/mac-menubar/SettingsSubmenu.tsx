import React from "react";
import { MacMenu } from "./MacMenu";
import { MenuItem, MenuSeparator } from "./MenuItem";
import { CheckboxItem } from "./CheckboxItem";
import { QualitySlider } from "./QualitySlider";

/**
 * Settings submenu matching real StatusBarController.buildSettingsSubmenu().
 * Updated to include all real menu items.
 */
export const SettingsSubmenu: React.FC<{
  scale?: number;
  qualityValue?: number;
  autoTranscribe?: boolean;
  diarization?: boolean;
  monitorDisk?: boolean;
  launchAtLogin?: boolean;
  format?: string;
  speakers?: string;
  fileTypes?: string;
  saveNextToFile?: boolean;
}> = ({
  scale = 1,
  qualityValue = 2,
  autoTranscribe = true,
  diarization = true,
  monitorDisk = false,
  launchAtLogin = true,
  format = "Markdown (.md)",
  speakers = "Авто",
  fileTypes = "Только аудио",
  saveNextToFile = true,
}) => (
  <MacMenu width={280} scale={scale}>
    <CheckboxItem label="Автотранскрибация" checked={autoTranscribe} scale={scale} />
    <MenuSeparator scale={scale} />
    <MenuItem
      label={`Качество: ${
        qualityValue === 0
          ? "Быстро"
          : qualityValue === 1
          ? "Экономно"
          : qualityValue === 2
          ? "Сбалансировано"
          : qualityValue === 3
          ? "Качественно"
          : "Максимум"
      }`}
      disabled
      scale={scale}
    />
    <QualitySlider value={qualityValue} scale={scale} />
    <MenuItem label="Детальные настройки..." scale={scale} />
    <MenuSeparator scale={scale} />
    <CheckboxItem
      label="Диаризация (разделение голосов)"
      checked={diarization}
      scale={scale}
    />
    <MenuItem label={`Спикеры: ${speakers}`} hasSubmenu scale={scale} />
    <MenuItem label={`Формат: ${format}`} hasSubmenu scale={scale} />
    <MenuItem label={`Типы файлов: ${fileTypes}`} hasSubmenu scale={scale} />
    <MenuSeparator scale={scale} />
    <CheckboxItem label="Мониторить весь диск" checked={monitorDisk} scale={scale} />
    <MenuItem label="Папки: Zoom" scale={scale} />
    <MenuSeparator scale={scale} />
    <CheckboxItem label="Сохранять рядом с файлом" checked={saveNextToFile} scale={scale} />
    <MenuItem label="Транскрипции: ~/Downloads" scale={scale} />
    <MenuSeparator scale={scale} />
    <CheckboxItem label="Запускать при входе в систему" checked={launchAtLogin} scale={scale} />
  </MacMenu>
);
