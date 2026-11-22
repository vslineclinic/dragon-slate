extends TestCase

const Store = preload("res://godot/ui/store.gd")


func test_unlock_only_on_victory() -> void:
	assert_eq(Store.next_unlocked(0, "gameOver", 0, 5), 0)
	assert_eq(Store.next_unlocked(0, "victory", 0, 5), 1)


func test_lower_clear_preserves_unlocks() -> void:
	assert_eq(Store.next_unlocked(3, "victory", 1, 5), 3)


func test_capped_at_max_level() -> void:
	assert_eq(Store.next_unlocked(5, "victory", 5, 5), 5)
	assert_eq(Store.next_unlocked(1, "victory", 1, 1), 1)
