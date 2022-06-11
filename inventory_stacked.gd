extends Inventory
class_name InventoryStacked
tool

signal capacity_changed;
signal occupied_space_changed;

const KEY_WEIGHT: String = "weight";
const KEY_STACK_SIZE: String = "default_stack_size";

export(float) var capacity: float setget _set_capacity;
var occupied_space: float;


func _get_configuration_warning() -> String:
    var space = _estimate_space();
    if space > capacity:
        return "Inventory capacity exceeded! %f/%f" % [space, capacity];
    return "";


func _estimate_space() -> float:
    var space = 0.0;
    for prototype_id in contents:
        space += _estimate_item_weight(prototype_id);
    return space;


func _estimate_item_weight(prototype_id: String) -> float:
    if item_protoset && item_protoset.has(prototype_id):
        var weight = item_protoset.get_item_property(prototype_id, KEY_WEIGHT, 1.0);
        var stack_size = item_protoset.get_item_property(prototype_id, KEY_STACK_SIZE, 1.0);
        return weight * stack_size;
    return 1.0;


static func get_item_script() -> Script:
    return preload("inventory_item_stackable.gd");


func _populate() -> void:
    ._populate();
    for item in get_items():
        if !item.get_prototype().empty() && item.get_prototype().has(KEY_STACK_SIZE):
            item.stack_size = item.get_prototype()[KEY_STACK_SIZE];


func has_unlimited_capacity() -> bool:
    return capacity == 0.0;


func _set_capacity(new_capacity: float) -> void:
    assert(new_capacity >= 0, "Capacity must be greater or equal to 0!");
    capacity = new_capacity;
    update_configuration_warning();
    emit_signal("capacity_changed");


func _set_contents(new_contents: Array) -> void:
    ._set_contents(new_contents);
    update_configuration_warning();


func _ready():
    _update_occupied_space();
    connect("contents_changed", self, "_on_contents_changed");


func _update_occupied_space() -> void:
    var old_occupied_space = occupied_space;
    occupied_space = 0.0;
    for item in get_items():
        occupied_space += _get_item_weight(item);

    if occupied_space != old_occupied_space:
        emit_signal("occupied_space_changed");

    if !Engine.editor_hint:
        assert(has_unlimited_capacity() || occupied_space <= capacity);


func _on_contents_changed():
    _update_occupied_space();


func get_free_space() -> float:
    if has_unlimited_capacity():
        return capacity;

    var free_space: float = capacity - occupied_space;
    if free_space < 0.0:
        free_space = 0.0
    return free_space;


func has_place_for(item: InventoryItem) -> bool:
    if has_unlimited_capacity():
        return true;

    return get_free_space() >= _get_item_weight(item);


func _get_item_unit_weight(item: InventoryItem) -> float:
    var weight = item.get_prototype_property(KEY_WEIGHT, 1.0);
    if weight is float:
        return weight;
    return 1.0;


func _get_item_weight(item: InventoryItem) -> float:
    return item.stack_size * _get_item_unit_weight(item);


func add_item(item: InventoryItem) -> bool:
    if has_place_for(item):
        return .add_item(item);

    return false;


func add_item_automerge(item: InventoryItem) -> bool:
    if !has_place_for(item):
        return false;

    var target_item = get_item_by_id(item.prototype_id);
    if target_item:
        add_item(item);
        target_item.join(item);
        return true;
    else:
        return add_item(item);


func transfer(item: InventoryItem, destination: Inventory) -> bool:
    assert(destination.get_class() == get_class());
    if !destination.has_place_for(item):
        return false;
    
    return .transfer(item, destination);


func transfer_autosplit(item: InventoryItem, destination: Inventory) -> bool:
    if destination.has_place_for(item):
        return transfer(item, destination);

    var count: int = int(destination.get_free_space()) / int(_get_item_unit_weight(item));
    if count > 0:
        var new_item: InventoryItem = item.split(count);
        assert(new_item != null);
        return transfer(new_item, destination);

    return false;


func transfer_automerge(item: InventoryItem, destination: Inventory) -> bool:
    if destination.has_place_for(item) && remove_item(item):
        return destination.add_item_automerge(item);

    return false;


func transfer_autosplitmerge(item: InventoryItem, destination: Inventory) -> bool:
    if destination.has_place_for(item):
        return transfer_automerge(item, destination);

    var count: int = int(destination.get_free_space()) / int(_get_item_unit_weight(item));
    if count > 0:
        var new_item: InventoryItem = item.split(count);
        assert(new_item != null);
        return transfer_automerge(new_item, destination);

    return false;
