import { applyCommand, createRun } from '../../core/src/index.ts';
import type { Command, GameData, GameEvent, RunState } from '../../core/src/index.ts';

type Listener = (events: GameEvent[], state: RunState) => void;

/** core 상태를 들고 있고, 명령을 적용해 구독자에게 이벤트를 넘긴다. */
export class GameController {
  readonly data: GameData;
  state: RunState;
  busy = false;
  private listeners: Listener[] = [];

  constructor(data: GameData, seed: number) {
    this.data = data;
    this.state = createRun(data, seed).state;
  }

  restart(seed: number): void {
    const r = createRun(this.data, seed);
    this.state = r.state;
    this.busy = false;
    this.emit(r.events);
  }

  dispatch(cmd: Command): GameEvent[] {
    if (this.busy) return [];
    const r = applyCommand(this.data, this.state, cmd);
    this.state = r.state;
    this.emit(r.events);
    return r.events;
  }

  on(fn: Listener): () => void {
    this.listeners.push(fn);
    return () => {
      this.listeners = this.listeners.filter((l) => l !== fn);
    };
  }

  private emit(events: GameEvent[]): void {
    for (const l of this.listeners) l(events, this.state);
  }
}
