// 기본 용을 원소별 12종으로 늘린다(형태 8가지 × 원소 6). 이미 있으면 건너뛴다.
// 같은 원소 조합표(역할 규칙)도 다시 만든다. 사용: node tools/gen-base-dragons.cjs
const fs = require('fs');
const read = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const dragons = read('data/dragons.json');
const traits = read('data/traits.json');
const codex = read('data/codex.json');
const recipes = read('data/recipes.json');

const ELEMENTS = {
  fire: ['fire', '불꽃'], ice: ['ice', '서리'], lightning: ['storm', '번개'],
  poison: ['poison', '독'], steel: ['steel', '강철'], abyss: ['abyss', '그림자'],
};
// [id, 이름, 역할, 체력, 공격력, 등장 비율, 특성 이름, 특성 종류, 값, 설명]
const FORMS = [
  ['lindworm', '린드부름', 'front', 135, 8, 30, '꼬리치기', 'atkPct', 10, '뒷다리 없이 앞발 둘로 기어 다니는 긴 용. 꼬리로 적을 후려친다.'],
  ['amphiptere', '암피프테르', 'back', 78, 12, 25, '활공', 'hastePct', 10, '다리 없이 날개만 가진 뱀 용. 바람을 타고 뒤에서 쏜다.'],
  ['wyrm', '웜', 'support', 105, 9, 25, '굴 파기', 'hpPct', 10, '땅속을 파고 다니는 굵은 용. 굴을 내어 아군을 돕는다.'],
  ['tortoise', '거북룡', 'front', 150, 7, 20, '등딱지', 'hpPct', 14, '단단한 등딱지를 진 느린 용. 맨 앞에서 버틴다.'],
  ['fairy', '요정룡', 'support', 85, 11, 12, '날개 가루', 'lifestealPct', 9, '나비 날개를 단 손바닥만 한 용. 가루를 뿌려 상처를 낫게 한다.'],
  ['raptor', '랩터룡', 'back', 88, 12, 20, '질주', 'hastePct', 12, '두 다리로 달리는 날쌘 용. 치고 빠지기를 잘한다.'],
  ['gecko', '도마뱀룡', 'back', 82, 11, 30, '재생 꼬리', 'lifestealPct', 6, '벽을 타는 작은 용. 꼬리가 잘려도 금세 자란다.'],
  ['horned', '뿔룡', 'front', 125, 10, 15, '뿔 돌진', 'atkPct', 12, '머리에 큰 뿔이 난 용. 고개를 숙이고 곧장 들이받는다.'],
];
const has = (id) => dragons.some((d) => d.id === id);
let added = 0;
for (const [element, [prefix, word]] of Object.entries(ELEMENTS)) {
  for (const [form, name, role, hp, atk, weight, traitName, kind, value, lore] of FORMS) {
    const id = `${prefix}_${form}`;
    if (has(id)) continue;
    dragons.push({ id, nameKo: `${word} ${name}`, tier: 'base', elements: [element], role, stats: { hp, atk, cooldownTicks: 20 }, traitId: 'tr_' + id, weight });
    traits.push({ id: 'tr_' + id, nameKo: `${word} ${traitName}`, kind, value });
    codex.push({ id, hintKo: '룬 석판의 알에서 나온다.', loreKo: lore });
    added++;
  }
}
const ELS = Object.keys(ELEMENTS);
const TIERS = ['base', 't2', 't1', 'apex', 'dual', 'secret'];
const pure = dragons.filter((d) => d.elements.length === 1);
const rest = dragons.filter((d) => d.elements.length !== 1);
pure.sort((a, b) => ELS.indexOf(a.elements[0]) - ELS.indexOf(b.elements[0]) || TIERS.indexOf(a.tier) - TIERS.indexOf(b.tier));
const sorted = pure.concat(rest);
const byId = Object.fromEntries(sorted.map((d) => [d.id, d]));
const kept = recipes.filter((r) => !(byId[r.a].elements.length === 1 && byId[r.b].elements.length === 1 && byId[r.result].elements.length === 1));
const third = (x, y) => ['front', 'back', 'support'].find((r) => r !== x && r !== y);
const same = [];
for (const el of ELS) {
  const of = (tier) => pure.filter((d) => d.elements[0] === el && d.tier === tier);
  const base = of('base'), t2 = of('t2'), t1 = of('t1'), apex = of('apex')[0];
  for (let i = 0; i < base.length; i++) for (let j = i; j < base.length; j++) {
    const role = base[i].role === base[j].role ? base[i].role : third(base[i].role, base[j].role);
    same.push({ a: base[i].id, b: base[j].id, result: t2.find((d) => d.role === role).id });
  }
  const frontT1 = t1.find((d) => d.role === 'front'), otherT1 = t1.find((d) => d.role !== 'front');
  for (let i = 0; i < t2.length; i++) for (let j = i; j < t2.length; j++) {
    const front = t2[i].role === 'front' || t2[j].role === 'front';
    same.push({ a: t2[i].id, b: t2[j].id, result: (front ? frontT1 : otherT1).id });
  }
  for (let i = 0; i < t1.length; i++) for (let j = i; j < t1.length; j++) same.push({ a: t1[i].id, b: t1[j].id, result: apex.id });
}
const line = (rows) => '[\n' + rows.map((r) => '  ' + JSON.stringify(r)).join(',\n') + '\n]\n';
fs.writeFileSync('data/dragons.json', line(sorted));
fs.writeFileSync('data/traits.json', line(traits));
fs.writeFileSync('data/codex.json', JSON.stringify(codex, null, 2) + '\n');
fs.writeFileSync('data/recipes.json', line(same.concat(kept)));
console.log('added', added, 'dragons', sorted.length, 'base per element', pure.filter((d) => d.tier === 'base').length / 6, 'recipes', same.length + kept.length);
