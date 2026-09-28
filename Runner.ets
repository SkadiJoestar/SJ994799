import { preferences } from '@kit.ArkData';
import { KeyCode } from '@kit.InputKit';
import { RunnerGame, ObstacleKind, Obstacle, Kunai, Particle, Boss, NinjaStyle, NINJA_STYLES } from '../game/RunnerModel';

@Entry
@Component
struct Runner {
  private renderCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private game: RunnerGame = new RunnerGame();
  private timerId: number = -1;
  private ready: boolean = false;
  private prefs: preferences.Preferences | undefined = undefined;
  private touchStartY: number = -1;
  private touchSlid: boolean = false;
  private deathFrames: number = 0;
  @State score: number = 0;
  @State bestScore: number = 0;
  @State distanceM: number = 0;
  @State killCount: number = 0;
  @State bossSlain: number = 0;
  @State scrollCount: number = 0;
  @State ammoCount: number = 15;
  @State gameState: string = 'start';
  @State ninjaIndex: number = 0;

  aboutToAppear(): void {
    try {
      const context = this.getUIContext().getHostContext();
      if (context !== undefined) {
        this.prefs = preferences.getPreferencesSync(context, { name: 'runner_game' });
        this.bestScore = this.prefs.getSync('best_score', 0) as number;
        const savedNinja: number = this.prefs.getSync('ninja_index', 0) as number;
        this.ninjaIndex = savedNinja >= 0 && savedNinja < NINJA_STYLES.length ? savedNinja : 0;
      }
    } catch (e) {
      this.prefs = undefined;
    }
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private tick(): void {
    if (this.gameState !== 'playing') {
      return;
    }
    this.game.update();
    if (this.game.isDead) {
      this.deathFrames += 1;
      this.draw();
      if (this.deathFrames > 24) {
        this.gameState = 'gameover';
        if (this.score > this.bestScore) {
          this.bestScore = this.score;
          this.saveBest();
        }
      }
      return;
    }
    this.score = this.game.score();
    this.distanceM = Math.floor(this.game.distance / 20);
    this.killCount = this.game.kills;
    this.bossSlain = this.game.bossCount;
    this.scrollCount = this.game.scrolls;
    this.ammoCount = this.game.kunaiAmmo;
    this.draw();
  }

  private saveBest(): void {
    if (this.prefs !== undefined) {
      try {
        this.prefs.putSync('best_score', this.bestScore);
      } catch (e) {
      }
      this.prefs.flush().catch(() => {
      });
    }
  }

  private selectNinja(index: number): void {
    this.ninjaIndex = index;
    if (this.prefs !== undefined) {
      try {
        this.prefs.putSync('ninja_index', index);
      } catch (e) {
      }
      this.prefs.flush().catch(() => {
      });
    }
  }

  private startGame(): void {
    this.game.reset();
    this.score = 0;
    this.distanceM = 0;
    this.killCount = 0;
    this.bossSlain = 0;
    this.scrollCount = 0;
    this.ammoCount = this.game.kunaiAmmo;
    this.deathFrames = 0;
    this.gameState = 'playing';
    this.stopTimer();
    this.timerId = setInterval(() => {
      this.tick();
    }, 33);
    this.draw();
  }

  private doAttack(): void {
    if (this.gameState === 'playing') {
      this.game.attack();
    }
  }

  private onCanvasReady(): void {
    const w: number = this.renderCtx.width;
    const h: number = this.renderCtx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.game.resize(w, h);
    this.game.reset();
    this.ready = true;
    this.draw();
  }

  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.renderCtx;
    if (!this.ready) {
      return;
    }
    const w: number = ctx.width;
    const h: number = ctx.height;
    ctx.save();
    if (this.game.shake > 0) {
      ctx.translate((Math.random() - 0.5) * this.game.shake, (Math.random() - 0.5) * this.game.shake);
    }
    this.drawRoom(ctx, w, h);
    this.drawCeiling(ctx, w);
    this.drawGround(ctx, w, h);
    this.drawObstacles(ctx);
    this.drawBoss(ctx);
    this.drawKunais(ctx);
    this.drawParticles(ctx);
    if (!this.game.isDead) {
      this.drawPlayer(ctx);
    }
    this.drawHp(ctx);
    if (this.game.boss.active && this.game.boss.dying === 0) {
      this.drawBossHp(ctx, w);
    }
    ctx.restore();
  }

  private drawRoom(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    const gy: number = this.game.groundY;
    const cy: number = this.game.ceilingY;
    const wall: CanvasGradient = ctx.createLinearGradient(0, 0, 0, h);
    wall.addColorStop(0, '#191210');
    wall.addColorStop(0.55, '#211813');
    wall.addColorStop(1, '#2A1F16');
    ctx.fillStyle = wall;
    ctx.fillRect(-20, -20, w + 40, h + 40);

    const span: number = 250;
    const off: number = (this.game.distance * 0.1) % span;
    for (let x = -off - span; x < w + span; x += span) {
      const sx: number = x + 24;
      const sy: number = gy - 262;
      const sw: number = span - 70;
      const sh: number = 212;
      ctx.globalAlpha = 0.14;
      ctx.fillStyle = '#EBDCB2';
      ctx.fillRect(sx, sy, sw, sh);
      ctx.globalAlpha = 0.22;
      ctx.strokeStyle = '#6A5A3E';
      ctx.lineWidth = 2;
      ctx.beginPath();
      for (let gx: number = sx + 36; gx < sx + sw - 6; gx += 36) {
        ctx.moveTo(gx, sy + 4);
        ctx.lineTo(gx, sy + sh - 4);
      }
      for (let gyy: number = sy + 56; gyy < sy + sh - 6; gyy += 56) {
        ctx.moveTo(sx + 4, gyy);
        ctx.lineTo(sx + sw - 4, gyy);
      }
      ctx.stroke();
      ctx.globalAlpha = 1.0;
      ctx.strokeStyle = '#0E0A07';
      ctx.lineWidth = 6;
      ctx.strokeRect(sx, sy, sw, sh);
    }

    const pspan: number = 190;
    const poff: number = (this.game.distance * 0.28) % pspan;
    for (let x = -poff - pspan; x < w + pspan; x += pspan) {
      ctx.fillStyle = '#140E09';
      ctx.fillRect(x, cy - 20, 24, gy - cy + 20);
      ctx.fillStyle = '#2C2014';
      ctx.fillRect(x, cy - 20, 5, gy - cy + 20);
    }

    const sspan: number = 380;
    const soff: number = (this.game.distance * 0.28) % sspan;
    for (let x = -soff - sspan; x < w + sspan; x += sspan) {
      const hx: number = x + 60;
      const hy: number = cy + 14;
      const hw: number = 34;
      const hh: number = 92;
      ctx.fillStyle = '#3A2A18';
      ctx.fillRect(hx - 4, hy - 5, hw + 8, 6);
      ctx.fillRect(hx - 4, hy + hh - 1, hw + 8, 6);
      ctx.fillStyle = '#D8CBA8';
      ctx.fillRect(hx, hy, hw, hh);
      ctx.fillStyle = '#2A2A34';
      ctx.beginPath();
      ctx.moveTo(hx + 4, hy + hh - 18);
      ctx.lineTo(hx + hw * 0.45, hy + 26);
      ctx.lineTo(hx + hw - 4, hy + hh - 18);
      ctx.closePath();
      ctx.fill();
    }

    const lspan: number = 300;
    const loff: number = (this.game.distance * 0.18) % lspan;
    for (let x = -loff - lspan; x < w + lspan; x += lspan) {
      const lx: number = x + 130;
      const sway: number = Math.sin(this.game.tickCount * 0.02 + lx * 0.01) * 3;
      const ly: number = cy + 30;
      ctx.strokeStyle = '#3A2A18';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(lx, cy - 18);
      ctx.lineTo(lx + sway, ly - 12);
      ctx.stroke();
      ctx.globalAlpha = 0.16;
      ctx.fillStyle = '#E8B85A';
      ctx.beginPath();
      ctx.arc(lx + sway, ly, 24, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 0.9;
      ctx.fillStyle = '#D9A455';
      ctx.beginPath();
      ctx.ellipse(lx + sway, ly, 10, 13, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#7A5A2E';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(lx + sway - 10, ly - 5);
      ctx.lineTo(lx + sway + 10, ly - 5);
      ctx.moveTo(lx + sway - 10, ly + 5);
      ctx.lineTo(lx + sway + 10, ly + 5);
      ctx.stroke();
      ctx.globalAlpha = 1.0;
    }
  }

  private drawCeiling(ctx: CanvasRenderingContext2D, w: number): void {
    const cy: number = this.game.ceilingY;
    ctx.fillStyle = '#0F0A06';
    ctx.fillRect(-20, cy - 30, w + 40, 34);
    ctx.fillStyle = '#2E1F12';
    ctx.fillRect(-20, cy - 30, w + 40, 7);
    ctx.fillStyle = '#3D2C1A';
    ctx.fillRect(-20, cy - 2, w + 40, 6);
    const span: number = 170;
    const off: number = (this.game.distance * 0.45) % span;
    for (let x = -off - span; x < w + span; x += span) {
      ctx.fillStyle = '#1A120A';
      ctx.fillRect(x, cy - 30, 20, 34);
      ctx.fillStyle = '#241A0E';
      ctx.fillRect(x + 17, cy - 30, 3, 34);
    }
  }

  private drawGround(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    const gy: number = this.game.groundY;
    ctx.fillStyle = '#221910';
    ctx.fillRect(-20, gy, w + 40, h - gy + 20);
    ctx.fillStyle = '#4A3620';
    ctx.fillRect(-20, gy, w + 40, 3);
    ctx.fillStyle = '#382815';
    ctx.fillRect(-20, gy + 3, w + 40, 2);
    ctx.strokeStyle = '#140E08';
    ctx.lineWidth = 2;
    const span: number = 95;
    const off: number = this.game.distance % span;
    ctx.beginPath();
    for (let x = -off; x < w + span; x += span) {
      ctx.moveTo(x, gy + 5);
      ctx.lineTo(x - 8, h + 20);
    }
    ctx.stroke();
    ctx.strokeStyle = '#3A2A18';
    ctx.lineWidth = 2;
    const off2: number = (this.game.distance * 1.2) % 70;
    ctx.beginPath();
    for (let x = -off2; x < w + 70; x += 70) {
      ctx.moveTo(x, gy + 16);
      ctx.lineTo(x + 34, gy + 16);
      ctx.moveTo(x + 20, gy + 34);
      ctx.lineTo(x + 52, gy + 34);
    }
    ctx.stroke();
  }

  private drawObstacles(ctx: CanvasRenderingContext2D): void {
    for (let i = 0; i < this.game.obstacles.length; i++) {
      const o: Obstacle = this.game.obstacles[i];
      if (o.ceil) {
        ctx.save();
        ctx.translate(0, o.y * 2);
        ctx.scale(1, -1);
      }
      if (o.kind === ObstacleKind.Box) {
        this.drawBox(ctx, o);
      } else if (o.kind === ObstacleKind.Bomb) {
        this.drawBomb(ctx, o);
      } else if (o.kind === ObstacleKind.Enemy) {
        this.drawEnemy(ctx, o);
      } else if (o.kind === ObstacleKind.Crow) {
        this.drawCrow(ctx, o);
      } else if (o.kind === ObstacleKind.Spike) {
        this.drawSpike(ctx, o);
      } else if (o.kind === ObstacleKind.Scroll) {
        this.drawScroll(ctx, o);
      } else if (o.kind === ObstacleKind.Blade) {
        this.drawBlade(ctx, o);
      } else if (o.kind === ObstacleKind.Ammo) {
        this.drawAmmoPickup(ctx, o);
      } else if (o.kind === ObstacleKind.Heart) {
        this.drawHeartPickup(ctx, o);
      } else {
        this.drawBolt(ctx, o);
      }
      if (o.ceil) {
        ctx.restore();
      }
    }
  }

  private drawBox(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    ctx.fillStyle = '#6E4A28';
    ctx.fillRect(o.x - o.size / 2, o.y - o.size / 2, o.size, o.size);
    ctx.strokeStyle = '#4A3118';
    ctx.lineWidth = 2;
    ctx.strokeRect(o.x - o.size / 2, o.y - o.size / 2, o.size, o.size);
    ctx.beginPath();
    ctx.moveTo(o.x - o.size / 2, o.y - o.size / 2);
    ctx.lineTo(o.x + o.size / 2, o.y + o.size / 2);
    ctx.moveTo(o.x + o.size / 2, o.y - o.size / 2);
    ctx.lineTo(o.x - o.size / 2, o.y + o.size / 2);
    ctx.stroke();
  }

  private drawBomb(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    ctx.strokeStyle = '#6A6A80';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(o.x, o.y - o.size / 2);
    ctx.lineTo(o.x, o.y - o.size / 2 - 5);
    ctx.stroke();
    if (this.game.tickCount % 10 < 5) {
      ctx.fillStyle = '#FFD866';
      ctx.beginPath();
      ctx.arc(o.x, o.y - o.size / 2 - 6, 3, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = '#34344A';
    ctx.beginPath();
    ctx.arc(o.x, o.y, o.size / 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#50506A';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(o.x - 6, o.y - 6, o.size / 4, Math.PI * 0.7, Math.PI * 1.4);
    ctx.stroke();
  }

  private drawEnemy(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    ctx.fillStyle = '#3A3A52';
    ctx.fillRect(o.x - 11, o.y - 26, 22, 22);
    ctx.beginPath();
    ctx.arc(o.x, o.y - 33, 8, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#E05050';
    ctx.fillRect(o.x - 6, o.y - 36, 4, 3);
    ctx.fillRect(o.x + 2, o.y - 36, 4, 3);
    ctx.strokeStyle = '#3A3A52';
    ctx.lineWidth = 4;
    const lunge: boolean = this.game.tickCount % 12 < 6;
    ctx.beginPath();
    ctx.moveTo(o.x, o.y - 6);
    ctx.lineTo(lunge ? o.x - 8 : o.x + 8, o.y);
    ctx.moveTo(o.x, o.y - 6);
    ctx.lineTo(lunge ? o.x + 8 : o.x - 6, o.y);
    ctx.stroke();
  }

  private drawCrow(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    const flap: number = Math.sin(this.tickPhase(o)) * 10;
    ctx.fillStyle = '#101018';
    ctx.beginPath();
    ctx.ellipse(o.x, o.y, 11, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(o.x + 10, o.y - 4, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#E05050';
    ctx.beginPath();
    ctx.arc(o.x + 12, o.y - 5, 1.6, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#101018';
    ctx.beginPath();
    ctx.moveTo(o.x - 2, o.y - 3);
    ctx.lineTo(o.x - 14, o.y - 3 - flap);
    ctx.lineTo(o.x - 4, o.y + 2);
    ctx.closePath();
    ctx.moveTo(o.x + 2, o.y - 3);
    ctx.lineTo(o.x + 12, o.y - 3 - flap * 0.6);
    ctx.lineTo(o.x + 4, o.y + 2);
    ctx.closePath();
    ctx.fill();
  }

  private drawSpike(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    ctx.fillStyle = '#B8B8C4';
    const n: number = 3;
    const sw: number = o.size / n;
    for (let i = 0; i < n; i++) {
      const sx: number = o.x - o.size / 2 + i * sw;
      ctx.beginPath();
      ctx.moveTo(sx, o.y + o.size / 2);
      ctx.lineTo(sx + sw / 2, o.y + o.size / 2 - o.size);
      ctx.lineTo(sx + sw, o.y + o.size / 2);
      ctx.closePath();
      ctx.fill();
    }
    ctx.fillStyle = '#78788A';
    for (let i = 0; i < n; i++) {
      const sx: number = o.x - o.size / 2 + i * sw;
      ctx.beginPath();
      ctx.moveTo(sx + sw / 2, o.y + o.size / 2 - o.size);
      ctx.lineTo(sx + sw, o.y + o.size / 2);
      ctx.lineTo(sx + sw / 2, o.y + o.size / 2);
      ctx.closePath();
      ctx.fill();
    }
  }

  private drawScroll(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    const bob: number = Math.sin(this.game.tickCount * 0.08 + o.phase) * 4;
    const sy: number = o.y + bob;
    ctx.globalAlpha = 0.25;
    ctx.fillStyle = '#E8C86A';
    ctx.beginPath();
    ctx.arc(o.x, sy, 20, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1.0;
    ctx.fillStyle = '#E8C86A';
    ctx.fillRect(o.x - 10, sy - 13, 20, 26);
    ctx.fillStyle = '#F5E6BE';
    ctx.fillRect(o.x - 13, sy - 15, 6, 8);
    ctx.fillRect(o.x + 7, sy - 15, 6, 8);
    ctx.fillRect(o.x - 13, sy + 7, 6, 8);
    ctx.fillRect(o.x + 7, sy + 7, 6, 8);
    ctx.fillStyle = '#B89440';
    ctx.fillRect(o.x - 4, sy - 8, 8, 16);
  }

  private drawBolt(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    ctx.fillStyle = '#E05555';
    ctx.beginPath();
    ctx.moveTo(o.x - 10, o.y);
    ctx.lineTo(o.x + 8, o.y - 7);
    ctx.lineTo(o.x + 8, o.y + 7);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#F0A0A0';
    ctx.fillRect(o.x + 2, o.y - 2, 8, 4);
  }

  private drawBlade(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    const sway: number = Math.sin(this.game.tickCount * 0.05 + o.phase) * 3;
    const topY: number = o.y - o.h / 2;
    ctx.strokeStyle = '#4A4A62';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(o.x + sway, topY);
    ctx.lineTo(o.x + sway * 0.4, topY - 34);
    ctx.stroke();
    ctx.fillStyle = '#4A4A62';
    ctx.beginPath();
    ctx.arc(o.x + sway * 0.4, topY - 36, 4, 0, Math.PI * 2);
    ctx.fill();
    const bx: number = o.x + sway;
    ctx.fillStyle = '#26263A';
    ctx.beginPath();
    ctx.moveTo(bx - o.w / 2, topY);
    ctx.lineTo(bx + o.w / 2, topY);
    ctx.lineTo(bx + o.w / 2 - 8, topY + o.h);
    ctx.lineTo(bx - o.w / 2 + 8, topY + o.h);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#B8B8C8';
    ctx.beginPath();
    ctx.moveTo(bx - o.w / 2 + 8, topY + o.h);
    ctx.lineTo(bx + o.w / 2 - 8, topY + o.h);
    ctx.lineTo(bx + o.w / 2 - 14, topY + o.h - 4);
    ctx.lineTo(bx - o.w / 2 + 14, topY + o.h - 4);
    ctx.closePath();
    ctx.fill();
  }

  private drawAmmoPickup(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    const bob: number = Math.sin(this.game.tickCount * 0.08 + o.phase) * 4;
    const ay: number = o.y + bob;
    ctx.globalAlpha = 0.22;
    ctx.fillStyle = '#D8D8E4';
    ctx.beginPath();
    ctx.arc(o.x, ay, 20, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1.0;
    ctx.fillStyle = '#D8D8E4';
    for (let i = 0; i < 3; i++) {
      const kx: number = o.x - 8 + i * 8;
      ctx.fillRect(kx - 5, ay - 2, 10, 4);
      ctx.beginPath();
      ctx.moveTo(kx + 6, ay);
      ctx.lineTo(kx + 2, ay - 3);
      ctx.lineTo(kx + 2, ay + 3);
      ctx.closePath();
      ctx.fill();
    }
    ctx.strokeStyle = '#8A8AA0';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(o.x - 11, ay - 12);
    ctx.lineTo(o.x + 11, ay - 12);
    ctx.moveTo(o.x - 11, ay + 10);
    ctx.lineTo(o.x + 11, ay + 10);
    ctx.stroke();
  }

  private drawHeartPickup(ctx: CanvasRenderingContext2D, o: Obstacle): void {
    const bob: number = Math.sin(this.game.tickCount * 0.08 + o.phase) * 4;
    const hy: number = o.y + bob;
    const pulse: number = 1 + Math.sin(this.game.tickCount * 0.12 + o.phase) * 0.12;
    ctx.globalAlpha = 0.2;
    ctx.fillStyle = '#E05050';
    ctx.beginPath();
    ctx.arc(o.x, hy, 22 * pulse, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1.0;
    ctx.fillStyle = '#E05050';
    ctx.beginPath();
    ctx.arc(o.x, hy, 12 * pulse, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#F5A0A0';
    ctx.beginPath();
    ctx.arc(o.x - 4, hy - 4, 3.5, 0, Math.PI * 2);
    ctx.fill();
  }

  private drawHeartShape(ctx: CanvasRenderingContext2D, x: number, y: number, s: number,
    filled: boolean): void {
    ctx.beginPath();
    ctx.moveTo(x, y + s * 0.55);
    ctx.bezierCurveTo(x - s * 1.1, y - s * 0.35, x - s * 0.55, y - s * 1.05, x, y - s * 0.35);
    ctx.bezierCurveTo(x + s * 0.55, y - s * 1.05, x + s * 1.1, y - s * 0.35, x, y + s * 0.55);
    ctx.closePath();
    if (filled) {
      ctx.fillStyle = '#E05050';
      ctx.fill();
      ctx.fillStyle = '#F5A0A0';
      ctx.beginPath();
      ctx.arc(x - s * 0.35, y - s * 0.35, s * 0.18, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.strokeStyle = '#5A5A6E';
      ctx.lineWidth = 2;
      ctx.stroke();
    }
  }

  private drawHp(ctx: CanvasRenderingContext2D): void {
    for (let i = 0; i < this.game.maxHp; i++) {
      this.drawHeartShape(ctx, 24 + i * 30, 30, 10, i < this.game.hp);
    }
  }

  private tickPhase(o: Obstacle): number {
    return this.game.tickCount * 0.35 + o.phase * 3;
  }

  private drawBoss(ctx: CanvasRenderingContext2D): void {
    const b: Boss = this.game.boss;
    if (!b.active) {
      return;
    }
    let alpha: number = 1.0;
    let scale: number = 1.0;
    if (b.dying > 0) {
      alpha = b.dying / 32;
      scale = 1 + (1 - alpha) * 0.6;
    }
    ctx.globalAlpha = alpha;
    const r: number = 46 * scale;
    ctx.fillStyle = '#1C1C2E';
    ctx.beginPath();
    ctx.ellipse(b.x, b.y, r, r * 0.9, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#32324A';
    ctx.lineWidth = 5;
    ctx.beginPath();
    for (let a = 0; a < 8; a++) {
      const ang: number = a * Math.PI / 4 + b.hoverPhase;
      const lx: number = b.x + Math.cos(ang) * (r + 6);
      const ly: number = b.y + Math.sin(ang) * (r * 0.9 + 6);
      ctx.moveTo(b.x + Math.cos(ang) * r * 0.8, b.y + Math.sin(ang) * r * 0.7);
      ctx.lineTo(lx, ly);
    }
    ctx.stroke();
    ctx.fillStyle = '#0E0E18';
    ctx.beginPath();
    ctx.ellipse(b.x - 14, b.y + 16, 14, 9, 0.3, 0, Math.PI * 2);
    ctx.ellipse(b.x + 16, b.y + 18, 12, 8, -0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#F0F0E8';
    ctx.beginPath();
    ctx.ellipse(b.x - 6, b.y - 10, 15, 12, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#D03030';
    ctx.beginPath();
    const look: number = Math.sin(b.hoverPhase * 2) * 3;
    ctx.arc(b.x - 8 + look, b.y - 10, 6, 0, Math.PI * 2);
    ctx.arc(b.x + 4 + look, b.y - 10, 6, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#0E0E18';
    ctx.beginPath();
    ctx.arc(b.x - 8 + look, b.y - 10, 2.5, 0, Math.PI * 2);
    ctx.arc(b.x + 4 + look, b.y - 10, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#16161F';
    ctx.beginPath();
    ctx.moveTo(b.x - 20, b.y - 24);
    ctx.lineTo(b.x + 16, b.y - 30);
    ctx.lineTo(b.x + 22, b.y - 12);
    ctx.closePath();
    ctx.fill();
    ctx.globalAlpha = 1.0;
  }

  private drawBossHp(ctx: CanvasRenderingContext2D, w: number): void {
    const b: Boss = this.game.boss;
    const barW: number = w * 0.6;
    const bx: number = (w - barW) / 2;
    const by: number = 8;
    ctx.fillStyle = 'rgba(10,10,20,0.7)';
    ctx.fillRect(bx - 3, by - 3, barW + 6, 16);
    ctx.fillStyle = '#3A3A50';
    ctx.fillRect(bx, by, barW, 10);
    ctx.fillStyle = '#D03030';
    ctx.fillRect(bx, by, barW * b.hp / b.maxHp, 10);
    ctx.fillStyle = '#F0F0E8';
    ctx.font = '12px sans-serif';
    ctx.fillText('墨鬼', bx, by + 26);
  }

  private drawKunais(ctx: CanvasRenderingContext2D): void {
    ctx.fillStyle = '#E8E8F0';
    for (let i = 0; i < this.game.kunais.length; i++) {
      const k: Kunai = this.game.kunais[i];
      ctx.fillRect(k.x - 8, k.y - 2, 10, 4);
      ctx.beginPath();
      ctx.moveTo(k.x + 10, k.y);
      ctx.lineTo(k.x + 3, k.y - 3);
      ctx.lineTo(k.x + 3, k.y + 3);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = 'rgba(232,232,240,0.35)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(k.x - 20, k.y);
      ctx.lineTo(k.x - 8, k.y);
      ctx.stroke();
    }
  }

  private drawParticles(ctx: CanvasRenderingContext2D): void {
    for (let i = 0; i < this.game.particles.length; i++) {
      const p: Particle = this.game.particles[i];
      ctx.globalAlpha = Math.max(p.life / p.maxLife, 0);
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1.0;
  }

  private drawPlayer(ctx: CanvasRenderingContext2D): void {
    const style: NinjaStyle = NINJA_STYLES[this.ninjaIndex];
    const px: number = this.game.playerX;
    const py: number = this.game.playerY;
    const onCeil: boolean = this.game.upsideDown;
    const inAir: boolean = onCeil ? py > this.game.ceilingY + 2 : py < this.game.groundY - 2;
    const sliding: boolean = this.game.sliding && !inAir;
    const t: number = this.game.tickCount;
    const runPhase: number = t * 0.25;
    const sway: number = Math.sin(t * 0.2);
    const invulnBlink: boolean = this.game.invulnTimer > 0 && t % 8 < 4;
    const baseAlpha: number = invulnBlink ? 0.35 : 1.0;
    ctx.save();
    ctx.translate(px, py);
    if (onCeil) {
      ctx.scale(1, -1);
    }
    ctx.lineCap = 'round';
    ctx.globalAlpha = baseAlpha * 0.3;
    ctx.fillStyle = '#000000';
    ctx.beginPath();
    ctx.ellipse(0, -3, 16, 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = baseAlpha;

    if (sliding) {
      ctx.strokeStyle = style.scarf;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(-6, -12);
      ctx.quadraticCurveTo(-18, -14 + sway * 2, -30, -10 + sway * 4);
      ctx.stroke();
      ctx.fillStyle = style.bodyDark;
      ctx.beginPath();
      ctx.moveTo(-16, -5);
      ctx.quadraticCurveTo(-4, -16, 10, -14);
      ctx.quadraticCurveTo(17, -12, 15, -5);
      ctx.quadraticCurveTo(0, -1, -16, -5);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = style.band;
      ctx.fillRect(4, -23, 17, 4);
      ctx.beginPath();
      ctx.arc(14, -18, 7.5, 0, Math.PI * 2);
      ctx.fillStyle = style.bodyDark;
      ctx.fill();
      ctx.strokeStyle = style.band;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(5, -21);
      ctx.quadraticCurveTo(-6, -24 + sway * 2, -16, -20 + sway * 3);
      ctx.stroke();
      ctx.fillStyle = '#F0F0E8';
      ctx.fillRect(16, -20, 5, 3);
      ctx.fillStyle = style.pupil;
      ctx.fillRect(19, -20, 2, 3);
    } else {
      const legA: number = Math.sin(runPhase);
      const legB: number = Math.sin(runPhase + Math.PI);
      const bodyGrad: CanvasGradient = ctx.createLinearGradient(-10, -46, 10, -18);
      bodyGrad.addColorStop(0, style.bodyLight);
      bodyGrad.addColorStop(1, style.bodyDark);
      ctx.fillStyle = bodyGrad;
      ctx.beginPath();
      ctx.moveTo(-8, -36);
      ctx.quadraticCurveTo(-12, -26, -9, -17);
      ctx.lineTo(9, -17);
      ctx.quadraticCurveTo(12, -26, 8, -36);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = style.belt;
      ctx.fillRect(-9, -22, 18, 4);
      ctx.fillStyle = style.bodyDark;
      ctx.beginPath();
      ctx.arc(0, -44, 8.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = style.band;
      ctx.fillRect(-9, -49, 17, 5);
      ctx.strokeStyle = style.band;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-8, -47);
      ctx.quadraticCurveTo(-18, -49 + sway * 3, -27, -44 + sway * 4);
      ctx.moveTo(-8, -45);
      ctx.quadraticCurveTo(-17, -42 + sway * 2, -24, -37 + sway * 3);
      ctx.stroke();
      ctx.fillStyle = '#F0F0E8';
      ctx.beginPath();
      ctx.moveTo(2, -47);
      ctx.lineTo(7, -46);
      ctx.lineTo(7, -43);
      ctx.lineTo(2, -44);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = style.pupil;
      ctx.fillRect(5, -46, 2, 2.5);
      ctx.strokeStyle = style.scarf;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(-4, -38);
      ctx.quadraticCurveTo(-16, -36 + sway * 2, -26, -30 + sway * 3);
      ctx.stroke();
      ctx.save();
      ctx.translate(-2, -30);
      ctx.rotate(-0.7);
      ctx.fillStyle = style.sheath;
      ctx.fillRect(-3, -27, 6, 36);
      ctx.fillStyle = '#3A3A4A';
      ctx.fillRect(-3.5, -28, 7, 4);
      ctx.fillStyle = style.handle;
      ctx.fillRect(-2.5, 8, 5, 11);
      ctx.fillStyle = '#C8C8D4';
      ctx.fillRect(-2.5, 12, 5, 1.5);
      ctx.restore();
      ctx.strokeStyle = style.bodyDark;
      ctx.lineWidth = 4.5;
      const armSwing: number = Math.sin(runPhase + Math.PI) * 5;
      ctx.beginPath();
      ctx.moveTo(0, -32);
      ctx.quadraticCurveTo(6, -29 + armSwing * 0.3, 11, -24 + armSwing);
      ctx.stroke();
      ctx.lineWidth = 5;
      ctx.beginPath();
      if (inAir) {
        ctx.moveTo(0, -18);
        ctx.lineTo(7, -11);
        ctx.lineTo(13, -14);
        ctx.moveTo(0, -18);
        ctx.lineTo(-9, -8);
        ctx.lineTo(-15, -12);
      } else {
        ctx.moveTo(0, -18);
        ctx.lineTo(legA * 6, -9);
        ctx.lineTo(legA * 6 + (legA >= 0 ? 7 : -4), 0);
        ctx.moveTo(0, -18);
        ctx.lineTo(legB * 6, -9);
        ctx.lineTo(legB * 6 + (legB >= 0 ? 7 : -4), 0);
      }
      ctx.stroke();
    }
    ctx.restore();
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Column({ space: 2 }) {
            Text(`得分 ${this.score}`)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text(`最高 ${this.bestScore}`)
              .fontSize(14)
              .fontColor('#FFD866')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column({ space: 2 }) {
            Text(`距离 ${this.distanceM} m`)
              .fontSize(16)
              .fontColor('#FFFFFF')
            Text(`消灭 ${this.killCount}    鬼 ${this.bossSlain}    卷轴 ${this.scrollCount}`)
              .fontSize(14)
              .fontColor('#FF9E80')
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 12 })

        Canvas(this.renderCtx)
          .layoutWeight(1)
          .width('100%')
          .onReady(() => {
            this.onCanvasReady();
          })
          .onTouch((event: TouchEvent) => {
            this.onCanvasTouch(event);
          })

        Row({ space: 8 }) {
          Button('跳跃')
            .layoutWeight(1)
            .height(56)
            .fontSize(20)
            .backgroundColor('#2A5A8A')
            .focusOnTouch(false)
            .onClick(() => {
              this.game.jump();
            })
          Button('滑铲')
            .layoutWeight(1)
            .height(56)
            .fontSize(20)
            .backgroundColor('#3A6A4A')
            .focusOnTouch(false)
            .onClick(() => {
              if (this.gameState === 'playing') {
                this.game.slide();
              }
            })
          Button('翻转')
            .layoutWeight(1)
            .height(56)
            .fontSize(20)
            .backgroundColor('#6A4A8A')
            .focusOnTouch(false)
            .onClick(() => {
              if (this.gameState === 'playing') {
                this.game.flip();
              }
            })
          Button(this.ammoCount > 0 ? `飞镖 ${this.ammoCount}` : '镖 0')
            .layoutWeight(1)
            .height(56)
            .fontSize(20)
            .backgroundColor(this.ammoCount > 0 ? '#8A2A4A' : '#4A4A56')
            .fontColor(this.ammoCount > 0 ? '#FFFFFF' : '#9090A0')
            .focusOnTouch(false)
            .onClick(() => {
              this.doAttack();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 16 })
      }
      .width('100%')
      .height('100%')

      if (this.gameState !== 'playing') {
        Column({ space: 14 }) {
          Text(this.gameState === 'start' ? '影·忍跑酷' : '游戏结束')
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          if (this.gameState === 'start') {
            Row({ space: 12 }) {
              ForEach(NINJA_STYLES, (style: NinjaStyle, idx: number) => {
                NinjaCard({
                  cardIndex: idx,
                  isSelected: idx === this.ninjaIndex,
                  onSelectNinja: (i: number): void => {
                    this.selectNinja(i);
                  }
                })
              }, (style: NinjaStyle): string => style.name)
            }
            .padding({ top: 4, bottom: 4 })
          }
          if (this.gameState === 'gameover') {
            Text(`得分 ${this.score}`)
              .fontSize(26)
              .fontColor('#FFD866')
            Text(`跑动 ${this.distanceM} m    消灭 ${this.killCount}    斩鬼 ${this.bossSlain}    卷轴 ${this.scrollCount}`)
              .fontSize(16)
              .fontColor('#FF9E80')
          }
          Text(this.gameState === 'start'
            ? '点按跳跃，下滑铲，上滑或W键上下翻转，在地面与天花板间飞檐走壁！血球+1血，镖袋+5镖。键盘：空格跳/S铲/W翻/J镖。每400m墨鬼来袭，射它！'
            : '按空格或点击按钮重新开始')
            .fontSize(16)
            .fontColor('#A0A0C0')
            .textAlign(TextAlign.Center)
            .padding({ left: 30, right: 30 })
          Button(this.gameState === 'start' ? '开始游戏' : '再来一局')
            .width(180)
            .height(48)
            .fontSize(20)
            .backgroundColor('#4CAF50')
            .focusOnTouch(false)
            .onClick(() => {
              this.startGame();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#80000000')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0C0C1D')
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down) {
        this.onGameKey(event.keyCode);
      }
    })
  }

  private onCanvasTouch(event: TouchEvent): void {
    if (this.gameState !== 'playing') {
      return;
    }
    const y: number = event.touches[0].y;
    if (event.type === TouchType.Down) {
      this.touchStartY = y;
      this.touchSlid = false;
    } else if (event.type === TouchType.Move) {
      if (!this.touchSlid && this.touchStartY >= 0) {
        if (y - this.touchStartY > 40) {
          this.game.slide();
          this.touchSlid = true;
        } else if (y - this.touchStartY < -40) {
          this.game.flip();
          this.touchSlid = true;
        }
      }
    } else if (event.type === TouchType.Up) {
      if (!this.touchSlid && this.touchStartY >= 0 && Math.abs(y - this.touchStartY) < 30) {
        this.game.jump();
      }
      this.touchStartY = -1;
    }
  }

  private onGameKey(keyCode: number): void {
    if (this.gameState !== 'playing') {
      if (keyCode === KeyCode.KEYCODE_ENTER || keyCode === KeyCode.KEYCODE_SPACE) {
        this.startGame();
      }
      return;
    }
    if (keyCode === KeyCode.KEYCODE_SPACE) {
      this.game.jump();
    } else if (keyCode === KeyCode.KEYCODE_DPAD_UP || keyCode === KeyCode.KEYCODE_W) {
      this.game.flip();
    } else if (keyCode === KeyCode.KEYCODE_DPAD_DOWN || keyCode === KeyCode.KEYCODE_S) {
      this.game.slide();
    } else if (keyCode === KeyCode.KEYCODE_J || keyCode === KeyCode.KEYCODE_X) {
      this.game.attack();
    }
  }
}

function drawNinjaPortrait(ctx: CanvasRenderingContext2D, style: NinjaStyle): void {
  const w: number = ctx.width;
  const h: number = ctx.height;
  ctx.clearRect(0, 0, w, h);
  ctx.save();
  ctx.translate(w / 2, h - 4);
  const scale: number = h / 74;
  ctx.scale(scale, scale);
  ctx.lineCap = 'round';
  ctx.globalAlpha = 0.3;
  ctx.fillStyle = '#000000';
  ctx.beginPath();
  ctx.ellipse(0, -2, 15, 3.5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 1.0;
  const grad: CanvasGradient = ctx.createLinearGradient(-10, -46, 10, -18);
  grad.addColorStop(0, style.bodyLight);
  grad.addColorStop(1, style.bodyDark);
  ctx.fillStyle = grad;
  ctx.beginPath();
  ctx.moveTo(-8, -36);
  ctx.quadraticCurveTo(-12, -26, -9, -17);
  ctx.lineTo(9, -17);
  ctx.quadraticCurveTo(12, -26, 8, -36);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = style.belt;
  ctx.fillRect(-9, -22, 18, 4);
  ctx.fillStyle = style.bodyDark;
  ctx.beginPath();
  ctx.arc(0, -44, 8.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = style.band;
  ctx.fillRect(-9, -49, 17, 5);
  ctx.strokeStyle = style.band;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-8, -47);
  ctx.quadraticCurveTo(-18, -46, -27, -42);
  ctx.moveTo(-8, -45);
  ctx.quadraticCurveTo(-17, -41, -24, -36);
  ctx.stroke();
  ctx.fillStyle = '#F0F0E8';
  ctx.beginPath();
  ctx.moveTo(2, -47);
  ctx.lineTo(7, -46);
  ctx.lineTo(7, -43);
  ctx.lineTo(2, -44);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = style.pupil;
  ctx.fillRect(5, -46, 2, 2.5);
  ctx.strokeStyle = style.scarf;
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(-4, -38);
  ctx.quadraticCurveTo(-14, -35, -22, -30);
  ctx.stroke();
  ctx.save();
  ctx.translate(-2, -30);
  ctx.rotate(-0.7);
  ctx.fillStyle = style.sheath;
  ctx.fillRect(-3, -27, 6, 36);
  ctx.fillStyle = '#3A3A4A';
  ctx.fillRect(-3.5, -28, 7, 4);
  ctx.fillStyle = style.handle;
  ctx.fillRect(-2.5, 8, 5, 11);
  ctx.fillStyle = '#C8C8D4';
  ctx.fillRect(-2.5, 12, 5, 1.5);
  ctx.restore();
  ctx.strokeStyle = style.bodyDark;
  ctx.lineWidth = 4.5;
  ctx.beginPath();
  ctx.moveTo(0, -32);
  ctx.quadraticCurveTo(6, -28, 11, -23);
  ctx.stroke();
  ctx.lineWidth = 5;
  ctx.beginPath();
  ctx.moveTo(0, -18);
  ctx.lineTo(-7, -9);
  ctx.lineTo(-8, 0);
  ctx.moveTo(0, -18);
  ctx.lineTo(7, -9);
  ctx.lineTo(9, 0);
  ctx.stroke();
  ctx.restore();
}

@Component
struct NinjaCard {
  @Prop cardIndex: number = 0;
  @Prop isSelected: boolean = false;
  private cardCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  onSelectNinja: (index: number) => void = (index: number): void => {
  };

  build() {
    Column({ space: 4 }) {
      Canvas(this.cardCtx)
        .width(84)
        .height(96)
        .onReady(() => {
          drawNinjaPortrait(this.cardCtx, NINJA_STYLES[this.cardIndex]);
        })
      Text(NINJA_STYLES[this.cardIndex].name)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isSelected ? '#FFD866' : '#E8E8F0')
      Text(NINJA_STYLES[this.cardIndex].desc)
        .fontSize(10)
        .fontColor('#9090A8')
    }
    .padding({ top: 8, bottom: 8, left: 8, right: 8 })
    .borderRadius(12)
    .border({
      width: this.isSelected ? 2 : 1,
      color: this.isSelected ? '#FFD866' : '#3A3A50'
    })
    .backgroundColor(this.isSelected ? '#2A2438' : '#1A1A28')
    .onClick(() => {
      this.onSelectNinja(this.cardIndex);
    })
  }
}
