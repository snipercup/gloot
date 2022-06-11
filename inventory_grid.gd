extends Inventory
class_name InventoryGrid
tool

signal size_changed;

const KEY_WIDTH: String = "width";
const KEY_HEIGHT: String = "height";

export(int, 1, 100) var width: int = 10 setget _set_width;
export(int, 1, 100) var height: int = 10 setget _set_height;

var item_positions: Dictionary = {};


class Vector2i:    
    var x: int;
    var y: int;

    func _init(x_: int, y_:int):
        x = x_;
        y = y_;

    func _to_string():
        return "(%s, %s)" % [x, y];

    func area() -> int:
        return x * y;


class Block:
    var position: Vector2i;
    var size: Vector2i;

    func _init(position_: Vector2i, size_: Vector2i):
        position = position_;
        size = size_;

    func _to_string():
        return "(%s, %s, %s, %s)" % [position.x, position.y, size.x, size.y];

    func to_rect() -> Rect2:
        return Rect2(position.x, position.y, size.x, size.y);

    func intersects(b: Block) -> bool:
        var rect1 = b.to_rect();
        var rect2 = to_rect();
        return rect1.intersects(rect2);


class Space:
    var capacity: Vector2i;
    var reserved_blocks: Array;

    func _init(capacity_: Vector2i):
        capacity = capacity_;

    func reserve(size: Vector2i) -> bool:
        var block = _find_space(size);
        if block:
            reserved_blocks.append(block);
            return true;
        return false;

    func _find_space(size: Vector2i) -> Block:
        for x in range(capacity.x - (size.x - 1)):
            for y in range(capacity.y - (size.y - 1)):
                var block_pos: Vector2i = Vector2i.new(x, y);
                var block_size: Vector2i = Vector2i.new(size.x, size.y);
                var block: Block = Block.new(block_pos, block_size);
                if _rect_free(block):
                    return block;
        return null;

    func _rect_free(block: Block) -> bool:
        if block.position.x + block.size.x > capacity.x:
            return false;
        if block.position.y + block.size.y > capacity.y:
            return false;
    
        for item_block in reserved_blocks:
            if block.intersects(item_block):
                return false;
    
        return true;


func _get_configuration_warning() -> String:
    if !_estimate_fullness():
        return "Inventory capacity exceeded!";
    return "";


func _estimate_fullness() -> bool:
    var space: Space = Space.new(Vector2i.new(width, height));
    for prototype_id in contents:
        var prototype_size = _get_prototype_size(prototype_id);
        if !space.reserve(prototype_size):
            return false;
    return true;


func _get_prototype_size(prototype_id: String) -> Vector2i:
    if item_protoset:
        var width: int = item_protoset.get_item_property(prototype_id, KEY_WIDTH, 1);
        var height: int = item_protoset.get_item_property(prototype_id, KEY_HEIGHT, 1);
        return Vector2i.new(width, height);
    return Vector2i.new(1, 1);


static func get_item_script() -> Script:
    return preload("inventory_item_rect.gd");


func get_item_position(item: InventoryItem) -> Vector2:
    assert(item_positions.has(item), "The inventory does not contain this item!");
    return item_positions[item];


func get_item_size(item: InventoryItemRect) -> Vector2:
    var item_width: int = item.get_prototype_property(KEY_WIDTH, 1);
    var item_height: int = item.get_prototype_property(KEY_HEIGHT, 1);
    if item.rotated:
        var temp = item_width;
        item_width = item_height;
        item_height = temp;
    return Vector2(item_width, item_height);
    

func _ready():
    assert(width > 0, "Inventory width must be positive!");
    assert(height > 0, "Inventory height must be positive!");


func _set_width(new_width: int) -> void:
    assert(new_width > 0, "Inventory width must be positive!");
    width = new_width;
    update_configuration_warning();
    emit_signal("size_changed");


func _set_height(new_height: int) -> void:
    assert(new_height > 0, "Inventory height must be positive!");
    height = new_height;
    update_configuration_warning();
    emit_signal("size_changed");


func _set_contents(new_contents: Array) -> void:
    ._set_contents(new_contents);
    update_configuration_warning();


func _populate() -> void:
    contents.sort_custom(self, "_compare_prototypes");
    ._populate();


func _compare_prototypes(prototype_id_1: String, prototype_id_2: String) -> bool:
    var size_1 = _get_prototype_size(prototype_id_1);
    var size_2 = _get_prototype_size(prototype_id_2);
    return size_1.area() > size_2.area();


func add_item(item: InventoryItem) -> bool:
    assert(item is InventoryItemRect, "InventoryGrid can only hold InventoryItemRect");
    var free_place = find_free_place(item);
    if free_place.empty():
        return false;

    return add_item_at(item, free_place.x, free_place.y);


func add_item_at(item: InventoryItemRect, x: int, y: int) -> bool:
    var item_size = get_item_size(item);
    if rect_free(x, y, item_size.x, item_size.y):
        item_positions[item] = Vector2(x, y);
        return .add_item(item);

    return false;


func remove_item(item: InventoryItem) -> bool:
    if .remove_item(item):
        assert(item_positions.has(item));
        item_positions.erase(item);
        return true;
    return false;


func move_item(item: InventoryItemRect, x: int, y: int) -> bool:
    var item_size = get_item_size(item);
    if rect_free(x, y, item_size.x, item_size.y, item):
        item_positions[item] = Vector2(x, y);
        emit_signal("contents_changed");
        return true;

    return false;


func transfer(item: InventoryItem, destination: Inventory) -> bool:
    return transfer_to(item, destination, 0, 0);


func transfer_to(item: InventoryItemRect, destination: InventoryGrid, x: int, y: int) -> bool:
    var item_size = get_item_size(item);
    if destination.rect_free(x, y, item_size.x, item_size.y):
        if .transfer(item, destination):
            destination.move_item(item, x, y);
            return true;

    return false;


func rect_free(x: int, y: int, w: int, h: int, exception: InventoryItemRect = null) -> bool:
    if x + w > width:
        return false;
    if y + h > height:
        return false;

    for item in get_items():
        if item == exception:
            continue;
        var item_pos: Vector2 = get_item_position(item);
        var item_size: Vector2 = get_item_size(item);
        var rect1: Rect2 = Rect2(Vector2(x, y), Vector2(w, h));
        var rect2: Rect2 = Rect2(item_pos, item_size);
        if rect1.intersects(rect2):
            return false;

    return true;


func find_free_place(item: InventoryItemRect) -> Dictionary:
    var item_size = get_item_size(item);
    for x in range(width - (item_size.x - 1)):
        for y in range(height - (item_size.y - 1)):
            if rect_free(x, y, item_size.x, item_size.y):
                return {x = x, y = y};

    return {};


func _compare_items(item1: InventoryItemRect, item2: InventoryItemRect) -> bool:
    var rect1: Rect2 = Rect2(get_item_position(item1), get_item_size(item1));
    var rect2: Rect2 = Rect2(get_item_position(item2), get_item_size(item2));
    return rect1.get_area() > rect2.get_area();


func sort() -> bool:
    var item_array: Array;
    for item in get_items():
        item_array.append(item);
    item_array.sort_custom(self, "_compare_items");

    for item in get_items():
        remove_child(item);

    for item in item_array:
        var free_place: Dictionary = find_free_place(item);
        if free_place.empty():
            return false;
        add_item_at(item, free_place.x, free_place.y);

    return true;


func _is_sorted() -> bool:
    for item in get_items():
        var item_pos = get_item_position(item);
        var item_size = get_item_size(item);
        if !rect_free(item_pos.x, item_pos.y, item_size.x, item_size.y, item):
            return false;

    return true;
