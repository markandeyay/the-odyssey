extends GutTest
## M9 element hook: the Element resource shape, the always-false API on
## Lanka, unlock plumbing for later islands, and guards pinning the
## anti-scope rules (empty registry, no element input bindings).


func after_each() -> void:
	# Leave the system exactly as Lanka requires: empty and inert.
	ElementSystem.apply_save_data({})
	ElementSystem._registry.clear()


func test_element_resource_shape() -> void:
	var element: Element = Element.new()
	assert_eq(element.id, &"", "id defaults empty")
	assert_eq(element.display_name, "")
	assert_eq(element.sub_elements.size(), 0, "sub-element list starts empty")
	assert_false(element.unlocked, "nothing ships unlocked")


func test_inert_on_lanka() -> void:
	assert_eq(ElementSystem.registered_count(), 0, "the registry is empty on Lanka (§6)")
	assert_false(ElementSystem.has_element(&"fire"))
	assert_false(ElementSystem.has_element(&"water"))
	assert_eq(ElementSystem.get_unlocked().size(), 0)
	assert_null(ElementSystem.get_element(&"fire"))


func test_no_element_input_bindings() -> void:
	for action: StringName in InputMap.get_actions():
		var name: String = String(action).to_lower()
		assert_false(
			name.contains("element") or name.contains("bend"),
			"no element input bindings on Lanka (§6): found %s" % action
		)


func test_unlock_plumbing_for_later_islands() -> void:
	var element: Element = Element.new()
	element.id = &"earth"
	element.display_name = "Earth"
	element.sub_elements = [&"metal"]
	ElementSystem.register(element)
	assert_false(element.unlocked, "registering does not unlock")
	ElementSystem.unlock(&"earth")
	assert_true(ElementSystem.has_element(&"earth"))
	assert_true(element.unlocked, "unlock state syncs to the registered resource")
	assert_true(ElementSystem.get_unlocked().has(&"earth"))


func test_unlock_table_round_trip() -> void:
	ElementSystem.unlock(&"air")
	var saved: Dictionary = ElementSystem.get_save_data()
	ElementSystem.apply_save_data({})
	assert_false(ElementSystem.has_element(&"air"), "cleared")
	ElementSystem.apply_save_data(saved)
	assert_true(ElementSystem.has_element(&"air"), "the unlock table survives the save file")
