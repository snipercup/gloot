extends Inventory
class_name InventoryLimited

signal capacity_changed;
signal occupied_space_changed;

export(float) var capacity: float setget _set_capacity;
var occupied: float;


func _set_capacity(new_capacity: float) -> void:
    assert(new_capacity >= 0, "Capacity must be greater or equal to 0!");
    capacity = new_capacity;
    emit_signal("capacity_changed", capacity);


func _ready():
    _update_occupied_space();
    connect("contents_changed", self, "_on_contents_changed");


func _update_occupied_space() -> void:
    var old_occupied_space = occupied;
    occupied = 0.0;
    for item in get_items():
        occupied += item.get_weight();

    if occupied != old_occupied_space:
        emit_signal("occupied_space_changed");
    assert(occupied <= capacity);


func _on_contents_changed():
    _update_occupied_space();


func get_occupied_space() -> float:
    return occupied;


func get_free_space() -> float:
    var free_space: float = capacity - occupied;
    if free_space < 0.0:
        free_space = 0.0
    return free_space;


func has_place_for(item: InventoryItem) -> bool:
    return get_free_space() >= item.get_weight();


func add_item(item: InventoryItem) -> bool:
    if has_place_for(item):
        return .add_item(item);

    return false;


func transfer(item: InventoryItem, destination: Inventory) -> bool:
    assert(destination.get_class() == get_class())
    if !destination.has_place_for(item):
        return false;
    
    return .transfer(item, destination);
