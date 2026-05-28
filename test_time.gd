extends SceneTree
func _init():
    var start_dict = {
        "year": 2026,
        "month": 3,
        "day": 8,
        "hour": 0,
        "minute": 0,
        "second": 0
    }
    var start_unix = Time.get_unix_time_from_datetime_dict(start_dict)
    var dt = Time.get_datetime_dict_from_unix_time(start_unix)
    print("Weekday for 2026-03-08: ", dt.weekday)
    quit()
