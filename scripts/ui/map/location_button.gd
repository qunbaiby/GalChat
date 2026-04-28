extends Button

var location_id: String = ""

func setup(loc_data: Dictionary) -> void:
	location_id = loc_data.get("id", "")
	text = loc_data.get("name", "未知地点")
	
	var desc_label = get_node_or_null("DescLabel")
	if desc_label:
		desc_label.text = loc_data.get("description", "")

