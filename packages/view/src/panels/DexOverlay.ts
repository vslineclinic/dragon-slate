import Phaser from 'phaser';
import { activeElements, ELEMENTS } from '../../../core/src/index.ts';
import type { DragonSpec, GameData } from '../../../core/src/index.ts';
import type { GameController } from '../controller.ts';
import { loadDiscovered } from '../codex-store.ts';
import { dragonImage } from '../fx/sprites.ts';
import { COLOR, ELEMENT_KO, TIER_KO, UI } from '../layout.ts';
import { button, text } from '../ui.ts';

export interface CodexEntry { id: string; hintKo: string; loreKo: string }


/** 도감: 원소별 줄(기본 2, 2티어 3, 1티어 1) + 이중 3 + 숨은 1 */
export class DexOverlay {
  private scene: Phaser.Scene;
  private ctl: GameController;
  private codex: Map<string, CodexEntry>;
  private root: Phaser.GameObjects.Container | null = null;
  private detail: Phaser.GameObjects.Text | null = null;

  constructor(scene: Phaser.Scene, ctl: GameController, codex: CodexEntry[]) {
    this.scene = scene;
    this.ctl = ctl;
    this.codex = new Map(codex.map((c) => [c.id, c]));
  }

  private page: 'element' | 'dual' = 'element';

  /** 원소별 탭: 원소마다 한 줄(기본 2, 2티어 3, 1티어 1) / 이중·숨은 탭: 4줄 × 4칸 */
  private rows(data: GameData): { label: string; dragons: DragonSpec[] }[] {
    const all = Object.values(data.dragons);
    const order = (d: DragonSpec) => ['base', 't2', 't1'].indexOf(d.tier);
    if (this.page === 'element') {
      return activeElements(data).map((el) => ({
        label: ELEMENT_KO[el] ?? el,
        dragons: all.filter((d) => d.elements.length === 1 && d.elements[0] === el && d.tier !== 'secret').sort((a, b) => order(a) - order(b) || (a.id < b.id ? -1 : 1)),
      }));
    }
    const rank = (d: DragonSpec) => d.elements.map((e) => ELEMENTS.indexOf(e)).join(',');
    const rest = [...all.filter((d) => d.tier === 'dual').sort((a, b) => (rank(a) < rank(b) ? -1 : 1)), ...all.filter((d) => d.tier === 'secret')];
    const out: { label: string; dragons: DragonSpec[] }[] = [];
    for (let i = 0; i < rest.length; i += 4) out.push({ label: '', dragons: rest.slice(i, i + 4) });
    return out;
  }

  isOpen(): boolean {
    return this.root !== null;
  }

  open(): void {
    this.root?.destroy(true);
    const s = this.scene;
    const data = this.ctl.data;
    const found = loadDiscovered();
    const known = (d: DragonSpec) => d.tier === 'base' || found.has(d.id);
    this.ctl.busy = true;
    const root = s.add.container(0, 0).setDepth(90);
    const dim = s.add.rectangle(0, 0, 1280, 720, 0x000000, 0.75).setOrigin(0).setInteractive();
    const panel = s.add.rectangle(40, 24, 1200, 672, 0x1b1f2a).setOrigin(0).setStrokeStyle(2, UI.panelLine);
    const total = Object.keys(data.dragons).length;
    const count = Object.values(data.dragons).filter(known).length;
    root.add([dim, panel, text(s, 64, 40, '드래곤 도감   발견 ' + count + ' / ' + total, 22)]);
    const tab = (x: number, label: string, page: 'element' | 'dual') => {
      const b = button(s, x, 30, 150, 44, label, () => { this.page = page; this.open(); }, this.page === page ? 0x5f3dc4 : 0x2b3045);
      root.add(b.root);
    };
    tab(620, '원소별', 'element');
    tab(780, '이중·숨은', 'dual');
    root.add(button(s, 1110, 30, 110, 44, '닫기', () => this.close(), 0x2b3045).root);
    const rows = this.rows(data);
    const dual = this.page === 'dual';
    const cw = dual ? 250 : 150;
    const ch = dual ? 110 : 76;
    const x0 = dual ? 120 : 140;
    rows.forEach((row, ri) => {
      const y = 86 + ri * (ch + 6);
      if (row.label) root.add(text(s, 64, y + ch / 2, row.label, 15, UI.dim).setOrigin(0, 0.5));
      row.dragons.forEach((d, ci) => {
        const x = x0 + ci * (cw + 8);
        const isKnown = known(d);
        const hiddenSecret = d.tier === 'secret' && !isKnown;
        const cell = s.add.rectangle(x, y, cw, ch, 0x232838).setOrigin(0).setStrokeStyle(2, isKnown ? COLOR[d.elements[0] ?? 'fire'] : 0x3a4157);
        root.add(cell);
        const imgSize = ch - 22;
        if (hiddenSecret) root.add(text(s, x + 40, y + ch / 2, '?', 40, '#5c6378').setOrigin(0.5));
        else {
          const img = dragonImage(s, d.id, x + 8 + imgSize / 2, y + ch / 2, imgSize, true);
          if (img) {
            if (!isKnown) img.setTint(0x000000).setAlpha(0.85);
            root.add(img);
          }
        }
        root.add(text(s, x + imgSize + 16, y + 10, TIER_KO[d.tier], 11, UI.dim));
        root.add(text(s, x + imgSize + 16, y + 28, isKnown ? d.nameKo : '???', 13, isKnown ? UI.text : '#5c6378').setWordWrapWidth(cw - imgSize - 22));
        cell.setInteractive({ useHandCursor: true }).on('pointerdown', () => this.show(d, isKnown));
      });
    });
    this.detail = text(s, 64, 600, '드래곤을 누르면 설명이나 힌트를 볼 수 있어요.', 16, UI.text).setWordWrapWidth(1150).setLineSpacing(4);
    root.add(this.detail);
    this.root = root;
  }

  private show(d: DragonSpec, known: boolean): void {
    const c = this.codex.get(d.id);
    if (!this.detail) return;
    if (known) this.detail.setText(d.nameKo + ' (' + TIER_KO[d.tier] + ')\n' + (c?.loreKo ?? ''));
    else this.detail.setText('??? (' + (d.tier === 'secret' ? '숨은 드래곤' : TIER_KO[d.tier]) + ')\n힌트: ' + (c?.hintKo ?? '아직 알려지지 않았어요.'));
  }

  close(): void {
    this.root?.destroy(true);
    this.root = null;
    this.detail = null;
    this.ctl.busy = false;
  }
}
