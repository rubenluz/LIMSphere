class ConnectionModel {
  final String name;
  final String url;
  final String anonKey;

  ConnectionModel({
    required this.name,
    required this.url,
    required this.anonKey,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'anonKey': anonKey,
      };

  factory ConnectionModel.fromJson(Map<String, dynamic> json) {
    return ConnectionModel(
      name: json['name'],
      url: json['url'],
      anonKey: json['anonKey'],
    );
  }
}