// database_connection_model.dart - ConnectionModel: stores a Supabase project
// URL, anon key, and display name; JSON serialisation for SharedPreferences.


class ConnectionModel {
  String name;
  String url;
  String anonKey;
  DateTime? lastConnected;

  ConnectionModel({
    required this.name,
    required this.url,
    required this.anonKey,
    this.lastConnected,
  });

  factory ConnectionModel.fromJson(Map<String, dynamic> json) => ConnectionModel(
        name: json['name'] as String,
        url: json['url'] as String,
        anonKey: json['anonKey'] as String,
        lastConnected: json['lastConnected'] != null
            ? DateTime.tryParse(json['lastConnected'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'anonKey': anonKey,
        'lastConnected': lastConnected?.toIso8601String(),
      };
}
