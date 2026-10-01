extends TestCase


func test_customers_leave_when_patience_runs_out() -> void:
	var book := OrderBook.new()
	book.add("pizza_margherita", 10.0)
	book.add("bruschetta", 20.0)
	assert_empty(book.tick(9.0))
	assert_almost(OrderBook.patience_fraction(book.orders[0]), 0.1)
	var left := book.tick(1.5)
	assert_eq(left.size(), 1)
	assert_eq(left[0].dish, "pizza_margherita")
	assert_eq(book.lost, 1)
	assert_eq(book.active_count(), 1)


func test_fulfill_takes_oldest_matching_order() -> void:
	var book := OrderBook.new()
	var first := book.add("pizza_margherita", 50.0)
	book.add("bruschetta", 50.0)
	book.add("pizza_margherita", 50.0)
	assert_eq(book.fulfill("pizza_margherita").uid, first.uid)
	assert_true(book.fulfill("pasta_pomodoro").is_empty())
	assert_eq(book.served, 1)


func test_judges_never_leave() -> void:
	var book := OrderBook.new()
	book.add("pizza_margherita", -1.0)
	assert_empty(book.tick(1000.0))
	assert_eq(OrderBook.patience_fraction(book.orders[0]), 1.0)
