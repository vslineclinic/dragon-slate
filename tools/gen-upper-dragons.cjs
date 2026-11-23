// 윗계급 용을 원소별 2티어 9 · 1티어 6 · 정점 3으로 늘리고(이미 있으면 건너뜀), 조합표 전체를 다시 만든다.
// 조합 규칙: 결과의 역할 = 두 재료 역할이 같으면 그 역할, 다르면 남은 역할.
//           같은 역할 안에서 어느 종이 되는지는 (재료 순번 합) % 종 수 — 재료 조합에 따라 결과가 달라진다.
// 사용: node tools/gen-upper-dragons.cjs
const fs = require('fs');
const read = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const dragons = read('data/dragons.json');
const traits = read('data/traits.json');
const codex = read('data/codex.json');
const recipes = read('data/recipes.json');

// 원소: [id 접두, 2티어 수식어, 1티어 수식어, 정점 수식어]
const ELEMENTS = {
  fire: ['fire', '홍염', '태양', '화염'], ice: ['ice', '빙결', '만년설', '빙설'], lightning: ['storm', '뇌광', '폭풍', '뇌전'],
  poison: ['poison', '맹독', '독무', '맹독'], steel: ['steel', '철갑', '백금', '강철'], abyss: ['abyss', '암흑', '월식', '심연'],
};
// [id, 이름, 계급, 역할, 체력, 공격력, 쿨다운, 특성 이름, 종류, 값, 설명]
const FORMS = [
  ['armored', '갑주룡', 't2', 'front', 310, 16, 20, '겹갑옷', 'hpPct', 16, '온몸을 두꺼운 비늘 갑옷으로 두른 용. 물러서는 법이 없다.'],
  ['brawler', '투사룡', 't2', 'front', 270, 19, 20, '맨주먹', 'atkPct', 15, '굵은 앞발로 치고받는 싸움꾼 용.'],
  ['lancer', '창날 와이번', 't2', 'back', 170, 28, 20, '꿰뚫기', 'atkPct', 16, '창처럼 뾰족한 주둥이로 내리꽂는 와이번.'],
  ['twinhead', '쌍두 와이번', 't2', 'back', 185, 26, 20, '두 갈래 숨결', 'hastePct', 14, '머리가 둘이라 숨결도 두 배로 바쁘다.'],
  ['sage', '현자룡', 't2', 'support', 230, 21, 20, '오랜 지혜', 'lifestealPct', 12, '긴 수염을 늘어뜨린 늙은 용. 아는 것이 많다.'],
  ['dancer', '무희 서펜트', 't2', 'support', 210, 23, 20, '춤사위', 'hastePct', 12, '리본 같은 지느러미를 흔들며 춤추는 뱀 용.'],
  ['guardian', '수호룡', 't1', 'front', 660, 38, 18, '수호의 맹세', 'hpPct', 26, '성문처럼 커다란 몸으로 무리를 지키는 용.'],
  ['skylord', '천공룡', 't1', 'back', 400, 58, 18, '하늘의 군주', 'atkPct', 24, '구름 위를 다스리는 용. 내려다보며 쏜다.'],
  ['meteor', '유성룡', 't1', 'back', 380, 62, 18, '별똥 낙하', 'hastePct', 22, '별똥별처럼 떨어져 내리는 용.'],
  ['elder', '고룡', 't1', 'support', 500, 46, 18, '태고의 숨', 'lifestealPct', 18, '세상이 어릴 때부터 살아온 용.'],
  ['god', '룡신', 'apex', 'front', 1250, 70, 18, '신의 비늘', 'hpPct', 30, '용들이 신으로 모시는 용. 앞에 서면 산과 같다.'],
  ['king', '룡왕', 'apex', 'back', 780, 100, 18, '왕의 포효', 'hastePct', 28, '왕관을 쓴 용의 임금. 포효 한 번에 전장이 얼어붙는다.'],
];
const has = (id) => dragons.some((d) => d.id === id);
let added = 0;
for (const [element, [prefix, w2, w1, wa]] of Object.entries(ELEMENTS)) {
  for (const [form, name, tier, role, hp, atk, cd, traitName, kind, value, lore] of FORMS) {
    const id = `${prefix}_${form}`;
    if (has(id)) continue;
    const apex = tier === 'apex';
    const word = tier === 't2' ? w2 : tier === 't1' ? w1 : wa;
    dragons.push({ id, nameKo: apex ? word + name : `${word} ${name}`, tier, elements: [element], role, stats: { hp, atk, cooldownTicks: cd }, traitId: 'tr_' + id });
    traits.push({ id: 'tr_' + id, nameKo: `${word} ${traitName}`, kind, value });
    const hint = tier === 't2' ? '같은 원소의 기본 용 둘이 만나면 태어난다. 누구와 누구인지에 따라 달라진다.'
      : tier === 't1' ? '같은 원소의 2티어 둘이 만나면 깨어난다.' : '같은 원소의 1티어 둘이 만나면 눈을 뜬다.';
    codex.push({ id, hintKo: hint, loreKo: lore });
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

const third = (x, y) => ['front', 'back', 'support'].find((r) => r !== x && r !== y);
const out = [];
const of = (el, tier) => pure.filter((d) => d.elements[0] === el && d.tier === tier);
for (const el of ELS) {
  const ladder = [of(el, 'base'), of(el, 't2'), of(el, 't1'), of(el, 'apex')];
  for (let step = 0; step < 3; step++) {
    const from = ladder[step], to = ladder[step + 1];
    for (let i = 0; i < from.length; i++) for (let j = i; j < from.length; j++) {
      const role = from[i].role === from[j].role ? from[i].role : third(from[i].role, from[j].role);
      let group = to.filter((d) => d.role === role);
      if (group.length === 0) group = to;
      out.push({ a: from[i].id, b: from[j].id, result: group[(i + j) % group.length].id });
    }
  }
}
// 이중: 두 원소의 2티어 아무 조합. 숨은 용 조합은 그대로 둔다.
for (const dual of rest.filter((d) => d.tier === 'dual')) {
  for (const a of of(dual.elements[0], 't2')) for (const b of of(dual.elements[1], 't2')) out.push({ a: a.id, b: b.id, result: dual.id });
}
const secret = recipes.filter((r) => byId[r.result].tier === 'secret');
const line = (rows) => '[\n' + rows.map((r) => '  ' + JSON.stringify(r)).join(',\n') + '\n]\n';
fs.writeFileSync('data/dragons.json', line(sorted));
fs.writeFileSync('data/traits.json', line(traits));
fs.writeFileSync('data/codex.json', JSON.stringify(codex, null, 2) + '\n');
fs.writeFileSync('data/recipes.json', line(out.concat(secret)));
const count = (tier) => of('fire', tier).length;
console.log('added', added, 'dragons', sorted.length, 'per element', count('base'), count('t2'), count('t1'), count('apex'), 'recipes', out.length + secret.length);
const made = new Set(out.map((r) => r.result));
console.log('unreachable upper:', pure.filter((d) => d.tier !== 'base' && !made.has(d.id)).map((d) => d.id).join(' ') || 'none');
