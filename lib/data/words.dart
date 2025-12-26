
/// Categories for Stirnraten game
enum StirnratenCategory {
  anime,
  starWars,
  custom,
  films,
  series,
  music,
  celebrities,
  animals,
  food,
  places,
  jobs,
  tech,
  sports,
  kids,
  mythology,
  plants,
}

/// Data class for Stirnraten words
class StirnratenData {
  static const Map<StirnratenCategory, String> categoryNames = {
    StirnratenCategory.anime: 'Anime Edition',
    StirnratenCategory.starWars: 'Star Wars',
    StirnratenCategory.custom: 'Eigene Wörter',
    StirnratenCategory.films: 'Film & Kino',
    StirnratenCategory.series: 'Serien & TV',
    StirnratenCategory.music: 'Musik & Bands',
    StirnratenCategory.celebrities: 'Prominente',
    StirnratenCategory.animals: 'Tiere',
    StirnratenCategory.food: 'Essen & Getränke',
    StirnratenCategory.places: 'Orte & Länder',
    StirnratenCategory.jobs: 'Berufe',
    StirnratenCategory.tech: 'Technik & Gadgets',
    StirnratenCategory.sports: 'Sport & Spiele',
    StirnratenCategory.kids: 'Kinder & Kinderserien',
    StirnratenCategory.mythology: 'Mythologie & Fantasy',
    StirnratenCategory.plants: 'Pflanzen & Natur',
  };

  static const Map<StirnratenCategory, List<String>> words = {
    StirnratenCategory.anime: [
      "Naruto", "One Piece", "Dragon Ball Z", "Attack on Titan", "Death Note",
      "Demon Slayer", "Jujutsu Kaisen", "My Hero Academia", "Fullmetal Alchemist", "Pokemon",
      "Sailor Moon", "Tokyo Ghoul", "Hunter x Hunter", "Bleach", "Fairy Tail",
      "One Punch Man", "JoJo's Bizarre Adventure", "Code Geass", "Steins;Gate", "Haikyuu!!",
      "Blue Lock", "Chainsaw Man", "Spy x Family", "Vinland Saga", "Berserk",
      "Ghibli", "Luffy", "Goku", "Pikachu", "Sasuke",
      "Vegeta", "Zoro", "Levi Ackerman", "Light Yagami", "Eren Yeager",
      "Itachi", "Kakashi", "Tanjiro", "Nezuko", "Gojo Satoru",
      "Alucard", "Kenshin", "Naoki", "Nausicaa", "Shoyo Hinata",
      "Mikasa", "Soma", "Inosuke", "Sosuke Aizen", "Edward Elric",
    ],

    StirnratenCategory.starWars: [
      "Darth Vader", "Luke Skywalker", "Yoda", "Han Solo", "Princess Leia",
      "Chewbacca", "R2-D2", "C-3PO", "Obi-Wan Kenobi", "Anakin Skywalker",
      "Emperor Palpatine", "Darth Maul", "Stormtrooper", "Boba Fett", "Jabba the Hutt",
      "The Mandalorian", "Grogu", "Ahsoka Tano", "Kylo Ren", "Rey",
      "Millennium Falcon", "Death Star", "X-Wing", "TIE Fighter", "Lightsaber",
      "The Force", "Jedi", "Sith", "Tatooine", "Hoth",
      "Ewok", "Wookiee", "Droid", "Clone Trooper", "General Grievous",
      "Count Dooku", "Mace Windu", "Padmé Amidala", "Lando Calrissian", "Admiral Ackbar",
      "BB-8", "Jango Fett", "Poe Dameron", "Finn", "Rose Tico",
    ],

    StirnratenCategory.custom: [
      "C8", "Monster White", "Dein Vater", "Clash Royale", "Wlan",
    ],

    StirnratenCategory.films: [
      "Titanic", "The Matrix", "Forrest Gump", "Inception", "The Godfather",
      "Gladiator", "Avatar", "The Dark Knight", "Pulp Fiction", "Casablanca",
      "Jurassic Park", "Back to the Future", "Toy Story", "Rocky", "The Shawshank Redemption",
      "Terminator", "Alien", "Finding Nemo", "The Lion King", "Braveheart",
      "Fight Club", "The Social Network", "La La Land", "Parasite", "Mad Max",
      "Goodfellas", "Whiplash", "The Prestige", "Interstellar", "The Departed",
      "Amelie", "The Pianist", "Slumdog Millionaire", "The Silence of the Lambs", "Memento",
    ],

    StirnratenCategory.series: [
      "Stranger Things", "Breaking Bad", "Friends", "The Office", "Game of Thrones",
      "The Crown", "Sherlock", "The Simpsons", "Rick and Morty", "The Mandalorian",
      "Westworld", "Better Call Saul", "Black Mirror", "The Witcher", "Lost",
      "House of Cards", "True Detective", "Narcos", "Ozark", "Peaky Blinders",
      "Chernobyl", "Fargo", "How I Met Your Mother", "Grey's Anatomy", "Dexter",
      "Buffy the Vampire Slayer", "Doctor Who", "Star Trek", "Twin Peaks", "Firefly",
    ],

    StirnratenCategory.music: [
      "The Beatles", "Beyoncé", "Elvis Presley", "Michael Jackson", "Madonna",
      "Billie Eilish", "Coldplay", "Nirvana", "Queen", "Adele",
      "Drake", "Taylor Swift", "Kendrick Lamar", "Ed Sheeran", "Bruno Mars",
      "U2", "Bob Dylan", "Pink Floyd", "AC/DC", "The Rolling Stones",
      "Imagine Dragons", "Red Hot Chili Peppers", "The Weeknd", "Eminem", "Lady Gaga",
      "Daft Punk", "Green Day", "Metallica", "Rihanna", "Sia",
    ],

    StirnratenCategory.celebrities: [
      "Albert Einstein", "Beyoncé", "Barack Obama", "Angela Merkel", "Elon Musk",
      "Oprah Winfrey", "Taylor Swift", "Leonardo DiCaprio", "Rihanna", "Cristiano Ronaldo",
      "Lionel Messi", "Bill Gates", "Steve Jobs", "Keanu Reeves", "Brad Pitt",
      "Jennifer Lawrence", "Tom Hanks", "Morgan Freeman", "Emma Watson", "Nicki Minaj",
      "Meryl Streep", "Dwayne Johnson", "Scarlett Johansson", "Kehlani", "LeBron James",
      "Serena Williams", "Ellen DeGeneres", "Ariana Grande", "Will Smith", "Julia Roberts",
    ],

    StirnratenCategory.animals: [
      "Känguru", "Eule", "Seepferdchen", "Elefant", "Löwe",
      "Pinguin", "Koala", "Nashorn", "Giraffe", "Delfin",
      "Wal", "Hai", "Fuchs", "Bär", "Wolf",
      "Schmetterling", "Ameise", "Käfer", "Papagei", "Strauß",
      "Krokodil", "Schildkröte", "Flamingo", "Otter", "Robbe",
      "Igel", "Mücke", "Spinne", "Seelöwe", "Kolibri",
    ],

    StirnratenCategory.food: [
      "Pizza", "Sushi", "Cappuccino", "Spaghetti", "Burger",
      "Tiramisu", "Currywurst", "Croissant", "Ice Cream", "Schnitzel",
      "Paella", "Ramen", "Falafel", "Pancakes", "Donut",
      "Salad", "Steak", "Samosa", "Bratwurst", "Gulasch",
      "Kimchi", "Burrito", "Taco", "Poke Bowl", "Samosa",
      "Brownie", "Miso Soup", "Hummus", "Risotto", "Gazpacho",
    ],

    StirnratenCategory.places: [
      "Paris", "New York", "Mount Everest", "Berlin", "London",
      "Sydney", "Grand Canyon", "Tokyo", "Rome", "Machu Picchu",
      "Venice", "Istanbul", "Barcelona", "Amsterdam", "Prague",
      "Rio de Janeiro", "Cairo", "Bangkok", "Seoul", "Los Angeles",
      "San Francisco", "Moscow", "Helsinki", "Lisbon", "Vienna",
      "Reykjavik", "Athens", "Dubai", "Zurich", "Montreal",
    ],

    StirnratenCategory.jobs: [
      "Feuerwehrmann", "Bäcker", "Programmierer", "Arzt", "Lehrer",
      "Pilot", "Koch", "Ingenieur", "Gärtner", "Journalist",
      "Polizist", "Zahnarzt", "Mechaniker", "Elektriker", "Schneider",
      "Friseur", "Architekt", "Designer", "Tierarzt", "Bibliothekar",
      "Buchhalter", "Berater", "Taxifahrer", "Landschaftsgärtner", "Sozialarbeiter",
      "Physiotherapeut", "Übersetzer", "Florist", "Maurer", "Schreiner",
    ],

    StirnratenCategory.tech: [
      "Drohne", "Bluetooth", "Smartwatch", "Smartphone", "3D-Drucker",
      "Virtual Reality", "Roboter", "Künstliche Intelligenz", "Router", "USB",
      "Blockchain", "Cloud", "Server", "IoT", "GPS",
      "Drone", "Microchip", "GPU", "SSD", "RAM",
      "Compiler", "API", "SDK", "Framework", "Container",
      "Docker", "Kubernetes", "Firmware", "Sensor", "Modem",
    ],

    StirnratenCategory.sports: [
      "Tischtennis", "Marathon", "Schach", "Fußball", "Basketball",
      "Tennis", "Rugby", "Boxen", "Golf", "Eishockey",
      "Badminton", "Volleyball", "Cricket", "Baseball", "Surfing",
      "Snowboarding", "Skating", "Fencing", "Gymnastics", "Weightlifting",
      "Cycling", "Skiing", "Sailing", "Rowing", "Diving",
      "Judo", "Karate", "Taekwondo", "Bowling", "Handball",
    ],

    StirnratenCategory.kids: [
      "Winnie Pooh", "Pumuckl", "Sesamstraße", "Pipi Langstrumpf", "Peppa Wutz",
      "Der kleine Maulwurf", "Biene Maja", "Feuerwehrmann Sam", "Paw Patrol", "Bob der Baumeister",
      "Thomas die Lokomotive", "Käpt'n Sharky", "Heidi", "Pinocchio", "Peter Pan",
      "Alice", "Winnie", "Spongebob", "Dora", "Bluey",
      "Caillou", "Barbapapa", "Miffy", "Mickey Mouse", "Donald Duck",
      "Pingu", "Moomin", "The Little Mermaid", "Rapunzel", "Cinderella",
    ],

    StirnratenCategory.mythology: [
      "Drache", "Zeus", "Thor", "Einhorn", "Pegasus",
      "Medusa", "Hercules", "Odin", "Fenrir", "Hydra",
      "Minotaur", "Cerberus", "Anubis", "Isis", "Ra",
      "Kali", "Shiva", "Loki", "Valkyrie", "Avalon",
      "Fairy", "Mermaid", "Banshee", "Sphinx", "Chimera",
      "Gorgon", "Nymph", "Satyr", "Titan", "Prometheus",
    ],

    StirnratenCategory.plants: [
      "Sonnenblume", "Eiche", "Rose", "Tulpe", "Bambus",
      "Kaktus", "Lavendel", "Aloe Vera", "Bonsai", "Vogelbeere",
      "Ahorn", "Weide", "Gänseblümchen", "Orchidee", "Lotus",
      "Efeu", "Magnolie", "Oleander", "Hibiskus", "Basilikum",
      "Rosmarin", "Thymian", "Salbei", "Petersilie", "Koriander",
      "Zitrone", "Apfelbaum", "Olive", "Kiefer", "Zeder",
    ],
  };

  static List<String> getWords(StirnratenCategory category) {
    return words[category] ?? [];
  }
}
