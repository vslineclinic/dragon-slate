class_name Rng
extends RefCounted
## mulberry32. packages/core/src/rng.ts 와 비트 단위로 같은 결과.
## 모든 값은 부호 없는 32비트 범위(0..0xFFFFFFFF)로 유지한다.

const M32 := 0xFFFFFFFF

var _s: int


func _init(seed: int, state: int = -1) -> void:
	_s = (state if state >= 0 else seed) & M32


## Math.imul 의 하위 32비트(부호 없는 값)
static func imul(a: int, b: int) -> int:
	return (a * b) & M32


## Math.floor(a / b) 와 같은 정수 나눗셈(음수에서도)
static func fdiv(a: int, b: int) -> int:
	var q := a / b
	if a % b != 0 and ((a < 0) != (b < 0)):
		q -= 1
	return q


func next_u32() -> int:
	_s = (_s + 0x6D2B79F5) & M32
	var t := _s
	t = imul(t ^ (t >> 15), t | 1)
	t = t ^ ((t + imul(t ^ (t >> 7), t | 61)) & M32)
	return (t ^ (t >> 14)) & M32


func next_int(max_exclusive: int) -> int:
	return next_u32() % max_exclusive


## weights[i] 는 items[i] 의 가중치(정수)
func pick_weighted(items: Array, weights: Array) -> Variant:
	var total := 0
	for w in weights:
		total += int(w)
	var roll := next_u32() % total
	for i in items.size():
		roll -= int(weights[i])
		if roll < 0:
			return items[i]
	return items[items.size() - 1]


func state() -> int:
	return _s
