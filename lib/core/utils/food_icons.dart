import '../../data/models/food.dart';

/// The 6 "main" food categories shown as the primary browsing grid on the
/// Add Food screen, each mapping to one or more underlying `foods.category`
/// values. Any category not covered here shows up in the secondary
/// "More categories" list instead.
const Map<String, List<String>> kMainFoodCategoryGroups = {
  'Carbs': ['Bread', 'Rice', 'Pasta'],
  'Dairy': ['Dairy'],
  'Meat': ['Meat', 'Fish'],
  'Fruits': ['Fruits'],
  'Vegetables': ['Vegetables'],
  'Desserts': ['Desserts'],
};

/// Icon shown on each main-category tile.
const Map<String, String> kMainFoodCategoryEmoji = {
  'Carbs': '🍞',
  'Dairy': '🥛',
  'Meat': '🍗',
  'Fruits': '🍎',
  'Vegetables': '🥦',
  'Desserts': '🍬',
};

/// Fallback icon for any underlying `foods.category` value — used both for
/// "more categories" tiles and as the default icon for a food whose exact
/// name isn't in [_foodEmoji] below.
const Map<String, String> kCategoryEmoji = {
  'Bread': '🍞',
  'Rice': '🍚',
  'Pasta': '🍝',
  'Dairy': '🥛',
  'Meat': '🍗',
  'Fish': '🐟',
  'Fruits': '🍎',
  'Vegetables': '🥦',
  'Desserts': '🍬',
  'Drinks': '☕',
  'Fast Food': '🍔',
  'Generic Ingredients': '🧂',
  'Snacks': '🍿',
  'Traditional Meals': '🍲',
};

const String kDefaultFoodEmoji = '🍽️';

/// Icon for a category tile — main or "more".
String emojiForCategory(String category) =>
    kMainFoodCategoryEmoji[category] ?? kCategoryEmoji[category] ?? kDefaultFoodEmoji;

/// Icon for a specific food, e.g. "Butter" -> 🧈. Falls back to the food's
/// category icon (e.g. an unmapped dessert falls back to the Desserts
/// group's 🍬) and finally to a generic plate if the category itself is
/// unrecognized (custom/imported foods with an unexpected category string).
String emojiForFood(Food food) {
  final specific = _foodEmoji[food.name.toLowerCase()];
  if (specific != null) return specific;
  return kCategoryEmoji[food.category] ?? kDefaultFoodEmoji;
}

/// Per-food overrides for well-known items, keyed by lowercase food name.
/// Anything not listed here just uses its category's fallback icon —
/// intentionally not exhaustive.
const Map<String, String> _foodEmoji = {
  // Fruits
  'apple': '🍎',
  'banana': '🍌',
  'orange': '🍊',
  'grapes': '🍇',
  'mango': '🥭',
  'watermelon': '🍉',
  'strawberries': '🍓',
  'pineapple': '🍍',
  'peach': '🍑',

  // Vegetables
  'tomato': '🍅',
  'cucumber': '🥒',
  'carrot': '🥕',
  'spinach': '🥬',
  'broccoli': '🥦',
  'potato': '🥔',
  'onion': '🧅',
  'eggplant': '🍆',
  'bell pepper': '🫑',
  'garlic': '🧄',
  'lettuce': '🥬',

  // Dairy
  'whole milk': '🥛',
  'cheddar cheese': '🧀',
  'mozzarella': '🧀',
  'feta cheese': '🧀',
  'butter': '🧈',
  'paneer': '🧀',
  'eggs': '🥚',

  // Meat & fish
  'chicken breast (cooked)': '🍗',
  'chicken thigh (cooked)': '🍗',
  'beef (lean, cooked)': '🥩',
  'lamb (cooked)': '🥩',
  'ground beef (80/20, cooked)': '🥩',
  'beef liver (cooked)': '🥩',
  'turkey breast (cooked)': '🍗',
  'lamb kebab (grilled)': '🍢',
  'salmon (cooked)': '🐟',
  'tuna (canned in water)': '🐟',
  'tilapia (cooked)': '🐟',
  'shrimp (cooked)': '🦐',
  'hammour (grilled)': '🐟',
  'sardines (canned in oil)': '🐟',

  // Rice / pasta / bread
  'white rice (cooked)': '🍚',
  'basmati rice (cooked)': '🍚',
  'brown rice (cooked)': '🍚',
  'machboos rice': '🍛',
  'biryani rice': '🍛',
  'spaghetti (cooked)': '🍝',
  'penne (cooked)': '🍝',
  'macaroni and cheese': '🍝',
  'lasagna': '🍝',
  'white bread': '🍞',
  'whole wheat bread': '🍞',
  'khubz (arabic flatbread)': '🫓',
  'naan': '🫓',
  'roti / chapati': '🫓',
  'pretzel (brezel)': '🥨',
  'pita bread': '🫓',

  // Desserts
  'kheer (rice pudding)': '🍮',
  'black forest cake': '🎂',
  'apfelstrudel': '🥧',
  'ice cream (vanilla)': '🍦',
  'chocolate chip cookie': '🍪',
  'cheesecake': '🍰',

  // Fast food
  'cheeseburger': '🍔',
  'french fries': '🍟',
  'fried chicken (breaded)': '🍗',
  'shawarma (chicken wrap)': '🌯',
  'pizza (cheese, regular crust)': '🍕',
  'currywurst': '🌭',
  'döner kebab': '🥙',
  'samosa': '🥟',

  // Drinks
  'black tea': '🍵',
  'karak chai': '🍵',
  'arabic coffee (qahwa)': '☕',
  'orange juice': '🧃',
  'cola (regular)': '🥤',
  'laban (buttermilk)': '🥛',
  'mango lassi': '🥤',
  'beer (lager)': '🍺',
  'apfelschorle': '🧃',
  'water': '💧',

  // Snacks
  'almonds': '🌰',
  'pistachios': '🌰',
  'hummus': '🥣',
  'mixed nuts': '🥜',
  'popcorn (air-popped)': '🍿',
  'dark chocolate (70%)': '🍫',
  'pakora': '🥟',

  // Traditional meals
  'chicken biryani': '🍛',
  'daal (lentil curry)': '🍲',
  'chicken karahi': '🍲',
  'nihari': '🍲',
  'machboos (chicken)': '🍛',
  'muhammar (sweet rice)': '🍚',
  'couscous with vegetables': '🍲',
  'chorba (soup)': '🍲',
  'mansaf': '🍲',
  'falafel': '🧆',
  'kabsa (chicken)': '🍛',
  "schnitzel (pork, breaded)": '🍗',
  'sauerbraten': '🍖',
  'bratwurst': '🌭',
  'sauerkraut': '🥬',
  'kofta curry': '🍲',
  'saag (spinach curry)': '🍲',

  // Generic ingredients
  'olive oil': '🫒',
  'vegetable oil': '🫒',
  'salt': '🧂',
  'honey': '🍯',
  'all-purpose flour': '🌾',
  'chickpeas (cooked)': '🫘',
  'lentils (cooked)': '🫘',
  'black beans (cooked)': '🫘',
  'peanut butter': '🥜',

  // Pakistan
  'haleem': '🍲',
  'seekh kebab': '🍢',
  'chapli kebab': '🥘',
  'sindhi biryani': '🍛',
  'paya': '🍲',
  'roghni naan': '🫓',
  'doodh patti chai': '🍵',
  'sweet lassi': '🥤',
  'sohan halwa': '🍬',
  'jalebi': '🍯',

  // Bahrain / Gulf
  'balaleet': '🍮',
  'harees': '🍲',
  'khubz regag': '🫓',
  'chebab (khameer)': '🥞',
  'lugaimat': '🍩',
  'sambosa (bahraini)': '🥟',

  // Middle East
  'tabbouleh': '🥗',
  'fattoush': '🥗',
  'shakshuka': '🍳',
  'mujaddara': '🍲',
  'baba ganoush': '🍆',
  "manakish (za'atar)": '🫓',
  'umm ali': '🍮',
  'msakhan': '🌯',

  // Germany
  'rouladen': '🥩',
  'kartoffelsalat': '🥔',
  'frikadellen': '🍔',
  'spätzle': '🍝',
  'stollen': '🍞',

  // Algeria
  'bourek': '🥟',
  'rechta': '🍜',
  'mhadjeb': '🫓',
  'chakhchoukha': '🍲',
  'zlabia': '🍥',
};
