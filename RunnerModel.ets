export enum ObstacleKind {
  Box = 0,
  Bomb = 1,
  Enemy = 2,
  Crow = 3,
  Spike = 4,
  Scroll = 5,
  Bolt = 6,
  Blade = 7,
  Ammo = 8,
  Heart = 9
}

export class Obstacle {
  kind: ObstacleKind = ObstacleKind.Box;
  x: number = 0;
  y: number = 0;
  baseY: number = 0;
  size: number = 28;
  w: number = 28;
  h: number = 28;
  phase: number = 0;
  ceil: boolean = false;
  alive: boolean = true;

  static create(kind: ObstacleKind, x: number, y: number, size: number): Obstacle {
    const o = new Obstacle();
    o.kind = kind;
    o.x = x;
    o.y = y;
    o.baseY = y;
    o.size = size;
    o.w = size;
    o.h = size;
    o.phase = Math.random() * Math.PI * 2;
    return o;
  }
}

export class Kunai {
  x: number = 0;
  y: number = 0;
  alive: boolean = true;

  static create(x: number, y: number): Kunai {
    const k = new Kunai();
    k.x = x;
    k.y = y;
    return k;
  }
}

export class Particle {
  x: number = 0;
  y: number = 0;
  vx: number = 0;
  vy: number = 0;
  life: number = 0;
  maxLife: number = 1;
  color: string = '#1A1A24';
  size: number = 3;

  static create(x: number, y: number, vx: number, vy: number, life: number,
    color: string, size: number): Particle {
    const p = new Particle();
    p.x = x;
    p.y = y;
    p.vx = vx;
    p.vy = vy;
    p.life = life;
    p.maxLife = life;
    p.color = color;
    p.size = size;
    return p;
  }
}

export class Boss {
  active: boolean = false;
  entering: boolean = false;
  x: number = 0;
  y: number = 0;
  hp: number = 24;
  maxHp: number = 24;
  fireCooldown: number = 70;
  hoverPhase: number = 0;
  dying: number = 0;
  lowShot: boolean = false;

  reset(hp: number): void {
    this.active = true;
    this.entering = true;
    this.hp = hp;
    this.maxHp = hp;
    this.fireCooldown = 70;
    this.hoverPhase = 0;
    this.dying = 0;
    this.lowShot = false;
  }
}

export class RunnerGame {
  width: number = 360;
  height: number = 640;
  groundY: number = 500;
  ceilingY: number = 270;
  upsideDown: boolean = false;
  playerX: number = 80;
  playerY: number = 500;
  playerVy: number = 0;
  jumpsLeft: number = 2;
  sliding: boolean = false;
  slideTimer: number = 0;
  obstacles: Obstacle[] = [];
  kunais: Kunai[] = [];
  particles: Particle[] = [];
  boss: Boss = new Boss();
  bossCount: number = 0;
  nextBossDistance: number = 9000;
  distance: number = 0;
  kills: number = 0;
  killPoints: number = 0;
  scrolls: number = 0;
  speed: number = 6;
  isDead: boolean = false;
  spawnCountdown: number = 300;
  attackCooldown: number = 0;
  kunaiAmmo: number = 15;
  kunaiMax: number = 20;
  ammoRegenTimer: number = 0;
  hp: number = 3;
  maxHp: number = 3;
  invulnTimer: number = 0;
  tickCount: number = 0;
  shake: number = 0;

  resize(width: number, height: number): void {
    this.width = width;
    this.height = height;
    this.groundY = height * 0.78;
    this.ceilingY = this.groundY - 230;
    if (this.ceilingY < 50) {
      this.ceilingY = 50;
    }
    this.playerX = width * 0.22;
  }

  reset(): void {
    this.playerY = this.groundY;
    this.playerVy = 0;
    this.jumpsLeft = 2;
    this.upsideDown = false;
    this.sliding = false;
    this.slideTimer = 0;
    this.obstacles = [];
    this.kunais = [];
    this.particles = [];
    this.boss = new Boss();
    this.bossCount = 0;
    this.nextBossDistance = 9000;
    this.distance = 0;
    this.kills = 0;
    this.killPoints = 0;
    this.scrolls = 0;
    this.speed = 6;
    this.isDead = false;
    this.spawnCountdown = 300;
    this.attackCooldown = 0;
    this.kunaiAmmo = 15;
    this.ammoRegenTimer = 0;
    this.hp = 3;
    this.invulnTimer = 0;
    this.tickCount = 0;
    this.shake = 0;
  }

  score(): number {
    return Math.floor(this.distance / 20) + this.killPoints;
  }

  jump(): void {
    if (this.isDead) {
      return;
    }
    if (this.jumpsLeft <= 0) {
      return;
    }
    this.sliding = false;
    this.slideTimer = 0;
    if (this.upsideDown) {
      this.playerVy = this.jumpsLeft === 2 ? 15 : 13;
    } else {
      this.playerVy = this.jumpsLeft === 2 ? -15 : -13;
    }
    this.jumpsLeft -= 1;
    this.burst(this.playerX, this.playerY, 4, '#3A3A55', 2);
  }

  flip(): void {
    if (this.isDead) {
      return;
    }
    this.upsideDown = !this.upsideDown;
    this.sliding = false;
    this.slideTimer = 0;
    this.playerVy = this.upsideDown ? -22 : 22;
    this.jumpsLeft = 1;
    this.burst(this.playerX, this.playerY, 8, '#F0F0E8', 2);
  }

  slide(): void {
    if (this.isDead) {
      return;
    }
    this.sliding = true;
    this.slideTimer = 26;
    if (this.upsideDown) {
      if (this.playerY > this.ceilingY + 2 && this.playerVy > -18) {
        this.playerVy = -18;
      }
    } else if (this.playerY < this.groundY - 2 && this.playerVy < 18) {
      this.playerVy = 18;
    }
  }

  attack(): void {
    if (this.isDead || this.attackCooldown > 0) {
      return;
    }
    if (this.kunaiAmmo <= 0) {
      return;
    }
    this.kunaiAmmo -= 1;
    let handY: number = 0;
    if (this.upsideDown) {
      handY = this.sliding ? this.playerY + 10 : this.playerY + 26;
    } else {
      handY = this.sliding ? this.playerY - 10 : this.playerY - 26;
    }
    this.kunais.push(Kunai.create(this.playerX + 20, handY));
    this.attackCooldown = 9;
  }

  update(): void {
    if (this.isDead) {
      this.updateParticles();
      if (this.shake > 0) {
        this.shake -= 1;
      }
      return;
    }
    this.tickCount += 1;
    const newSpeed: number = 4.5 + this.distance / 1000;
    this.speed = newSpeed > 11 ? 11 : newSpeed;
    this.distance += this.speed;
    if (this.attackCooldown > 0) {
      this.attackCooldown -= 1;
    }
    this.ammoRegenTimer += 1;
    if (this.ammoRegenTimer >= 60) {
      this.ammoRegenTimer = 0;
      if (this.kunaiAmmo < this.kunaiMax) {
        this.kunaiAmmo += 1;
      }
    }
    if (this.shake > 0) {
      this.shake -= 1;
    }
    if (this.invulnTimer > 0) {
      this.invulnTimer -= 1;
    }

    if (this.sliding) {
      this.slideTimer -= 1;
      if (this.slideTimer <= 0) {
        this.sliding = false;
      } else if (this.tickCount % 3 === 0) {
        if (!this.upsideDown && this.playerY >= this.groundY - 1) {
          this.particles.push(Particle.create(this.playerX - 14, this.groundY,
            -2 - Math.random() * 2, -Math.random() * 1.5, 12, '#2A2A3C', 3));
        } else if (this.upsideDown && this.playerY <= this.ceilingY + 1) {
          this.particles.push(Particle.create(this.playerX - 14, this.ceilingY + 4,
            -2 - Math.random() * 2, Math.random() * 1.5, 12, '#2A2A3C', 3));
        }
      }
    }

    this.playerVy += this.upsideDown ? -1.15 : 1.15;
    this.playerY += this.playerVy;
    if (!this.upsideDown) {
      if (this.playerY >= this.groundY) {
        if (this.playerVy > 6 && !this.sliding) {
          this.burst(this.playerX, this.groundY, 5, '#3A3A55', 2);
        }
        this.playerY = this.groundY;
        this.playerVy = 0;
        this.jumpsLeft = 2;
      }
    } else {
      if (this.playerY <= this.ceilingY) {
        if (this.playerVy < -6 && !this.sliding) {
          this.burst(this.playerX, this.ceilingY + 8, 5, '#3A3A55', 2);
        }
        this.playerY = this.ceilingY;
        this.playerVy = 0;
        this.jumpsLeft = 2;
      } else if (this.playerY >= this.groundY) {
        this.upsideDown = false;
        this.playerY = this.groundY;
        this.playerVy = 0;
        this.jumpsLeft = 2;
      }
    }

    this.updateBoss();

    if (!this.boss.active) {
      this.spawnCountdown -= this.speed;
      if (this.spawnCountdown <= 0) {
        this.spawnObstacle();
        this.spawnCountdown = 320 + Math.random() * 420;
      }
    }

    for (let i = 0; i < this.obstacles.length; i++) {
      const o: Obstacle = this.obstacles[i];
      let v: number = this.speed;
      if (o.kind === ObstacleKind.Enemy) {
        v += 2.5;
      } else if (o.kind === ObstacleKind.Bolt) {
        v += 5;
      } else if (o.kind === ObstacleKind.Crow) {
        v += 1.5;
        o.y = o.baseY + Math.sin(this.tickCount * 0.1 + o.phase) * 26;
      }
      o.x -= v;
    }
    for (let i = 0; i < this.kunais.length; i++) {
      const k: Kunai = this.kunais[i];
      k.x += this.speed + 14;
    }
    this.updateParticles();

    this.resolveKunaiHits();
    this.resolvePlayerHits();
    this.obstacles = this.obstacles.filter((o: Obstacle): boolean => o.alive && o.x > -60);
    this.kunais = this.kunais.filter((k: Kunai): boolean => k.alive && k.x < this.width + 60);
  }

  private updateParticles(): void {
    for (let i = 0; i < this.particles.length; i++) {
      const p: Particle = this.particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.25;
      p.life -= 1;
    }
    this.particles = this.particles.filter((p: Particle): boolean => p.life > 0);
  }

  private updateBoss(): void {
    const b: Boss = this.boss;
    if (!b.active) {
      if (this.distance >= this.nextBossDistance) {
        b.reset(24 + this.bossCount * 10);
        b.x = this.width + 90;
        b.y = this.groundY - 150;
      }
      return;
    }
    if (b.dying > 0) {
      b.dying -= 1;
      if (b.dying === 0) {
        b.active = false;
        this.bossCount += 1;
        this.nextBossDistance = this.distance + 10000 + this.bossCount * 3000;
      }
      return;
    }
    if (b.entering) {
      b.x -= 4;
      if (b.x <= this.width - 90) {
        b.entering = false;
      }
    } else {
      b.hoverPhase += 0.04;
      b.y = this.groundY - 150 + Math.sin(b.hoverPhase) * 38;
      b.fireCooldown -= 1;
      if (b.fireCooldown <= 0) {
        this.fireBolt();
        const cd: number = 72 - this.bossCount * 6;
        b.fireCooldown = cd < 42 ? 42 : cd;
      }
    }
  }

  private fireBolt(): void {
    const b: Boss = this.boss;
    const shotY: number = b.lowShot ? this.groundY - 30 : this.groundY - 115;
    const bolt: Obstacle = Obstacle.create(ObstacleKind.Bolt, b.x - 46, shotY, 18);
    this.obstacles.push(bolt);
    b.lowShot = !b.lowShot;
    this.burst(b.x - 46, shotY, 4, '#E05555', 2);
  }

  private resolveKunaiHits(): void {
    for (let i = 0; i < this.kunais.length; i++) {
      const k: Kunai = this.kunais[i];
      if (!k.alive) {
        continue;
      }
      if (this.hitBoss(k.x, k.y, 10)) {
        this.damageBoss(k.x, k.y);
        k.alive = false;
        continue;
      }
      for (let j = 0; j < this.obstacles.length; j++) {
        const o: Obstacle = this.obstacles[j];
        if (!o.alive) {
          continue;
        }
        if (o.kind === ObstacleKind.Spike || o.kind === ObstacleKind.Scroll ||
          o.kind === ObstacleKind.Blade || o.kind === ObstacleKind.Ammo ||
          o.kind === ObstacleKind.Heart) {
          continue;
        }
        const halfW: number = o.w / 2 + 8;
        const halfH: number = o.h / 2 + 8;
        const dx: number = k.x - o.x;
        const dy: number = k.y - o.y;
        if (dx > -halfW && dx < halfW && dy > -halfH && dy < halfH) {
          o.alive = false;
          k.alive = false;
          this.kills += 1;
          if (o.kind === ObstacleKind.Box) {
            this.killPoints += 10;
          } else if (o.kind === ObstacleKind.Bomb) {
            this.killPoints += 15;
          } else if (o.kind === ObstacleKind.Crow) {
            this.killPoints += 30;
          } else if (o.kind === ObstacleKind.Bolt) {
            this.killPoints += 5;
          } else {
            this.killPoints += 25;
          }
          this.burstObstacle(o);
          break;
        }
      }
    }
  }

  private resolvePlayerHits(): void {
    const bodyH: number = this.sliding ? 18 : 44;
    const px1: number = this.playerX - (this.sliding ? 14 : 12);
    const px2: number = this.playerX + (this.sliding ? 14 : 12);
    let py1: number = 0;
    let py2: number = 0;
    if (this.upsideDown) {
      py1 = this.playerY;
      py2 = this.playerY + bodyH;
    } else {
      py1 = this.playerY - bodyH;
      py2 = this.playerY;
    }

    if (this.boss.active && this.boss.dying === 0 && !this.boss.entering) {
      if (px2 > this.boss.x - 44 && px1 < this.boss.x + 44 &&
        py2 > this.boss.y - 40 && py1 < this.boss.y + 44) {
        if (this.invulnTimer <= 0) {
          this.hurt();
        }
        return;
      }
    }

    for (let i = 0; i < this.obstacles.length; i++) {
      const o: Obstacle = this.obstacles[i];
      if (!o.alive) {
        continue;
      }
      const ohW: number = o.w / 2;
      const ohH: number = o.h / 2;
      if (px2 > o.x - ohW && px1 < o.x + ohW && py2 > o.y - ohH && py1 < o.y + ohH) {
        if (o.kind === ObstacleKind.Scroll) {
          o.alive = false;
          this.scrolls += 1;
          this.killPoints += 50;
          this.burst(o.x, o.y, 10, '#E8C86A', 3);
          continue;
        }
        if (o.kind === ObstacleKind.Ammo) {
          o.alive = false;
          const gained: number = this.kunaiMax - this.kunaiAmmo;
          this.kunaiAmmo += gained < 5 ? gained : 5;
          this.burst(o.x, o.y, 10, '#D8D8E4', 3);
          continue;
        }
        if (o.kind === ObstacleKind.Heart) {
          o.alive = false;
          if (this.hp < this.maxHp) {
            this.hp += 1;
            this.burst(o.x, o.y, 12, '#E05050', 3);
          } else {
            this.killPoints += 20;
            this.burst(o.x, o.y, 8, '#FFD866', 3);
          }
          continue;
        }
        if (this.invulnTimer > 0) {
          continue;
        }
        o.alive = false;
        this.hurt();
        return;
      }
    }
  }

  private hurt(): void {
    this.hp -= 1;
    this.invulnTimer = 80;
    this.shake = 8;
    this.burst(this.playerX, this.playerY - 22, 12, '#E05050', 3);
    if (this.hp <= 0) {
      this.killPlayer();
    }
  }

  private hitBoss(x: number, y: number, r: number): boolean {
    const b: Boss = this.boss;
    if (!b.active || b.dying > 0 || b.entering) {
      return false;
    }
    return x > b.x - 48 - r && x < b.x + 48 + r && y > b.y - 42 - r && y < b.y + 46 + r;
  }

  private damageBoss(x: number, y: number): void {
    const b: Boss = this.boss;
    b.hp -= 1;
    this.burst(x, y, 6, '#1A1A24', 3);
    if (b.hp <= 0) {
      b.dying = 32;
      this.kills += 1;
      this.killPoints += 300;
      this.shake = 10;
      for (let i = 0; i < 3; i++) {
        this.burst(b.x + (Math.random() - 0.5) * 60, b.y + (Math.random() - 0.5) * 60,
          14, i === 0 ? '#E05555' : '#1A1A24', 4);
      }
    }
  }

  private killPlayer(): void {
    this.isDead = true;
    this.shake = 12;
    this.burst(this.playerX, this.playerY - 20, 16, '#E05050', 4);
    this.burst(this.playerX, this.playerY - 20, 20, '#1A1A24', 4);
    this.burst(this.playerX, this.playerY - 20, 12, '#F0F0E8', 3);
  }

  private spawnObstacle(): void {
    const r: number = Math.random();
    const toCeil: boolean = Math.random() < 0.35;
    if (r < 0.18) {
      this.pushObstacle(Obstacle.create(ObstacleKind.Box, this.width + 40, this.groundY - 15, 30), toCeil);
    } else if (r < 0.34) {
      const h: number = 70 + Math.random() * 80;
      this.pushObstacle(Obstacle.create(ObstacleKind.Bomb, this.width + 40, this.groundY - h, 26), toCeil);
    } else if (r < 0.5) {
      this.pushObstacle(Obstacle.create(ObstacleKind.Enemy, this.width + 40, this.groundY - 14, 28), toCeil);
    } else if (r < 0.62) {
      const h: number = 120 + Math.random() * 90;
      this.obstacles.push(Obstacle.create(ObstacleKind.Crow, this.width + 40, this.groundY - h, 26));
    } else if (r < 0.74) {
      this.pushObstacle(Obstacle.create(ObstacleKind.Spike, this.width + 40, this.groundY - 12, 34), toCeil);
    } else if (r < 0.8) {
      const h: number = 60 + Math.random() * 120;
      this.pushObstacle(Obstacle.create(ObstacleKind.Scroll, this.width + 40, this.groundY - h, 24), toCeil);
    } else if (r < 0.9) {
      const blade: Obstacle = Obstacle.create(ObstacleKind.Blade, this.width + 60, this.groundY - 46, 40);
      blade.w = 80;
      blade.h = 22;
      this.pushObstacle(blade, toCeil);
    } else if (r < 0.95) {
      const h: number = 60 + Math.random() * 100;
      this.pushObstacle(Obstacle.create(ObstacleKind.Ammo, this.width + 40, this.groundY - h, 24), toCeil);
    } else {
      const h: number = 60 + Math.random() * 110;
      this.pushObstacle(Obstacle.create(ObstacleKind.Heart, this.width + 40, this.groundY - h, 22), toCeil);
    }
  }

  private pushObstacle(o: Obstacle, toCeil: boolean): void {
    if (toCeil) {
      o.y = this.ceilingY + (this.groundY - o.y);
      o.baseY = o.y;
      o.ceil = true;
    }
    this.obstacles.push(o);
  }

  private burstObstacle(o: Obstacle): void {
    if (o.kind === ObstacleKind.Bomb) {
      this.burst(o.x, o.y, 12, '#FFD866', 3);
      this.burst(o.x, o.y, 8, '#1A1A24', 3);
    } else if (o.kind === ObstacleKind.Crow) {
      this.burst(o.x, o.y, 12, '#1A1A24', 4);
      this.burst(o.x, o.y, 6, '#F0F0E8', 2);
    } else if (o.kind === ObstacleKind.Bolt) {
      this.burst(o.x, o.y, 6, '#E05555', 3);
    } else {
      this.burst(o.x, o.y, 8, '#5C4A32', 3);
      this.burst(o.x, o.y, 6, '#1A1A24', 3);
    }
  }

  private burst(x: number, y: number, count: number, color: string, size: number): void {
    for (let i = 0; i < count; i++) {
      const ang: number = Math.random() * Math.PI * 2;
      const sp: number = 1.5 + Math.random() * 3;
      this.particles.push(Particle.create(x, y, Math.cos(ang) * sp, Math.sin(ang) * sp - 1,
        12 + Math.floor(Math.random() * 8), color, size));
    }
  }
}

export class NinjaStyle {
  name: string = '小黑';
  desc: string = '影之正统 墨黑忍装';
  bodyDark: string = '#16161E';
  bodyLight: string = '#2E2E40';
  band: string = '#E23E3E';
  scarf: string = '#E23E3E';
  belt: string = '#E23E3E';
  pupil: string = '#D03030';
  sheath: string = '#0C0C12';
  handle: string = '#7A2A2A';

  static create(name: string, desc: string, bodyDark: string, bodyLight: string,
    accent: string, pupil: string, sheath: string, handle: string): NinjaStyle {
    const s: NinjaStyle = new NinjaStyle();
    s.name = name;
    s.desc = desc;
    s.bodyDark = bodyDark;
    s.bodyLight = bodyLight;
    s.band = accent;
    s.scarf = accent;
    s.belt = accent;
    s.pupil = pupil;
    s.sheath = sheath;
    s.handle = handle;
    return s;
  }
}

export const NINJA_STYLES: NinjaStyle[] = [
  NinjaStyle.create('小黑', '影之正统 墨黑忍装', '#16161E', '#2E2E40', '#E23E3E', '#D03030', '#0C0C12', '#7A2A2A'),
  NinjaStyle.create('苍', '如风之刃 苍蓝忍装', '#101A2A', '#24486A', '#4A9AD4', '#4AC4E8', '#0A1018', '#2A4A7A'),
  NinjaStyle.create('烈', '烈焰之心 绯红忍装', '#201008', '#5A3014', '#F08A30', '#F0A030', '#160A04', '#8A4A1A')
];
