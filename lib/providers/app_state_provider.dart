import 'package:flutter/foundation.dart';
import '../models/anime.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/dummy_data.dart';

class AppStateProvider extends ChangeNotifier {
  //Data yang ingin disimpan di sini
  List<Anime> _favorites = [];

  //Kunci Penyimpanan
  static const String _storageKey = 'favorite_anime_list';

  //Constructor: otomatis memuat favorit saat provider dibuat
  AppStateProvider() {
    _loadFavorites();
  }

  //getters
  List<Anime> get favorites => List.unmodifiable(_favorites);

  //STATE BARU: genre yang dipilih (bisa lebih dari satu, kosong = "All")
  final Set<String> _selectedGenres = {};

  Set<String> get selectedGenres => Set.unmodifiable(_selectedGenres);

  //METHOD BARU: pilih/batal pilih genre. "All" mengosongkan semua pilihan
  void toggleGenre(String genre) {
    if (genre == "All") {
      _selectedGenres.clear();
    } else if (!_selectedGenres.remove(genre)) {
      _selectedGenres.add(genre);
    }
    notifyListeners();
  }

  //STATE BARU: query pencarian di HomeScreen
  String _homeSearchQuery = '';

  String get homeSearchQuery => _homeSearchQuery;

  void setHomeSearchQuery(String query) {
    _homeSearchQuery = query;
    notifyListeners();
  }

  //STATE BARU: query pencarian di FavoriteScreen
  String _favoriteSearchQuery = '';

  String get favoriteSearchQuery => _favoriteSearchQuery;

  void setFavoriteSearchQuery(String query) {
    _favoriteSearchQuery = query;
    notifyListeners();
  }

  //helper functions
  bool isFavorite(String id) {
    return _favorites.any((anime) => anime.id == id);
  }

  //method untuk menambahkan anime ke favorite
  void toggleFavorite(Anime anime) {
    if (isFavorite(anime.id)) {
      removeFavorite(anime.id);
    } else {
      addFavorite(anime);
    }
  }

  void removeFavorite(String id) {
    _favorites.removeWhere((anime) => anime.id == id);
    _saveFavorites();
    notifyListeners();
  }

  void addFavorite(Anime anime) {
    if (!isFavorite(anime.id)) {
      _favorites.add(anime);
      _saveFavorites();
      notifyListeners();
    }
  }

  //Cek apakah judul anime cocok dengan query (tidak peka huruf besar/kecil)
  bool _matchesQuery(Anime anime, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return anime.title.toLowerCase().contains(q);
  }

  List<Anime> getFilteredAnimeForHome() {
    List<Anime> result = DummyData.animeList;

    //Terapkan filter genre
    if (_selectedGenres.isNotEmpty) {
      result = result.where((anime) {
        //pecah "Action, Adventure" menjadi set {"Action", "Adventure"}
        final genres = anime.genre.split(',').map((g) => g.trim()).toSet();
        //Cek apakah anime punya SEMUA genre yang dipilih
        return genres.containsAll(_selectedGenres);
      }).toList();
    }

    //Terapkan filter pencarian
    return result.where((anime) => _matchesQuery(anime, _homeSearchQuery)).toList();
  }

  //Daftar favorit yang sudah difilter berdasarkan query pencarian
  List<Anime> getFilteredFavorites() {
    return _favorites
        .where((anime) => _matchesQuery(anime, _favoriteSearchQuery))
        .toList();
  }

  //Simpan daftar favorit ke SharedPreferences
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      //1. List<Anime> -> List<Map<String, dynamic>>
      final List<Map<String, dynamic>> favoritesJson =
          _favorites.map((anime) => anime.toJson()).toList();

      //2. List<Map> -> String JSON, lalu simpan
      await prefs.setString(_storageKey, jsonEncode(favoritesJson));
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  //Muat daftar favorit dari SharePreferences
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      //1. Baca String JSON
      final String? favoritesJson = prefs.getString(_storageKey);

      if (favoritesJson != null) {
        //2. String JSON -> List<dynamic>
        final List<dynamic> decode = jsonDecode(favoritesJson);

        //3. List<dynamic> -> List<Anime>
        _favorites = decode
            .map((item) => Anime.fromJson(item as Map<String, dynamic>))
            .toList();

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }
}
