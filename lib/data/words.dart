
/// Categories for Stirnraten game
enum StirnratenCategory {
  anime,
  starWars,
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
  videogames,
  superheroes,
  disney,
  youtubers,
  brands,
  nineties,
  twoThousands,
  history,
  pantomime,
  noises,
  household,
  bodyParts,
  books,
  cities,
  festivals,
  feelings,
  ownWords,
}

/// Data class for Stirnraten words
class StirnratenData {
  static const Map<StirnratenCategory, String> categoryNames = {
    StirnratenCategory.anime: 'Anime',
    StirnratenCategory.starWars: 'Star Wars',
    StirnratenCategory.films: 'Filme',
    StirnratenCategory.series: 'Serien',
    StirnratenCategory.music: 'Musik',
    StirnratenCategory.celebrities: 'Promis',
    StirnratenCategory.animals: 'Tiere',
    StirnratenCategory.food: 'Essen',
    StirnratenCategory.places: 'Orte',
    StirnratenCategory.jobs: 'Berufe',
    StirnratenCategory.tech: 'Technik',
    StirnratenCategory.sports: 'Sport',
    StirnratenCategory.kids: 'Kinder',
    StirnratenCategory.mythology: 'Mythen',
    StirnratenCategory.plants: 'Natur',
    StirnratenCategory.videogames: 'Gaming',
    StirnratenCategory.superheroes: 'Helden',
    StirnratenCategory.disney: 'Disney',
    StirnratenCategory.youtubers: 'YouTuber',
    StirnratenCategory.brands: 'Marken',
    StirnratenCategory.nineties: '90er',
    StirnratenCategory.twoThousands: '2000er',
    StirnratenCategory.history: 'Historisch',
    StirnratenCategory.pantomime: 'Pantomime',
    StirnratenCategory.noises: 'Geräusche',
    StirnratenCategory.household: 'Haushalt',
    StirnratenCategory.bodyParts: 'Körper',
    StirnratenCategory.books: 'Bücher',
    StirnratenCategory.cities: 'Städte',
    StirnratenCategory.festivals: 'Feste',
    StirnratenCategory.feelings: 'Gefühle',
    StirnratenCategory.ownWords: 'Eigene Wörter',
  };

  static const Map<StirnratenCategory, List<String>> words = {
    StirnratenCategory.ownWords: [
      "Dein Vater", 
    ],
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

    StirnratenCategory.videogames: [
      "Mario", "Minecraft", "Fortnite", "Zelda", "Among Us",
      "Pikachu", "PlayStation", "Xbox", "Nintendo", "Tetris",
      "Pac-Man", "Sonic", "Call of Duty", "GTA", "Sims",
      "League of Legends", "World of Warcraft", "Roblox", "Animal Crossing", "FIFA",
      "Clash Royale", "Brawl Stars", "Candy Crush", "Subway Surfers", "Temple Run",
    ],

    StirnratenCategory.superheroes: [
      "Spider-Man", "Batman", "Iron Man", "Wonder Woman", "Thanos",
      "Joker", "Superman", "Captain America", "Thor", "Hulk",
      "Black Widow", "Black Panther", "Deadpool", "Wolverine", "Flash",
      "Aquaman", "Green Lantern", "Doctor Strange", "Scarlet Witch", "Loki",
      "Groot", "Rocket Raccoon", "Star-Lord", "Gamora", "Drax",
    ],

    StirnratenCategory.disney: [
      "Micky Maus", "Elsa", "Simba", "Buzz Lightyear", "Arielle",
      "Shrek", "Donald Duck", "Goofy", "Pluto", "Minnie Maus",
      "Aladdin", "Dschinni", "Peter Pan", "Tinkerbell", "Cinderella",
      "Schneewittchen", "Dornröschen", "Rapunzel", "Vaiana", "Maui",
      "Woody", "Nemo", "Dorie", "Wall-E", "Ratatouille",
    ],

    StirnratenCategory.youtubers: [
      "MontanaBlack", "MrBeast", "Rezo", "BibisBeautyPalace", "Knossi",
      "Trymacs", "Unge", "Gronkh", "Julien Bam", "Dagi Bee",
      "Laserluca", "Paluten", "GermanLetsPlay", "Rewinside", "Sturmwaffel",
      "Kelly MissesVlog", "Freshtorge", "Die Lochis", "ApeCrime", "Space Frogs",
      "LeFloid", "HandOfBlood", "Papaplatte", "EliasN97", "Sidemen",
    ],

    StirnratenCategory.brands: [
      "Apple", "Nike", "McDonald's", "Tesla", "IKEA",
      "Coca-Cola", "Amazon", "Adidas", "Samsung", "Google",
      "Microsoft", "Netflix", "Spotify", "Instagram", "TikTok",
      "Facebook", "Twitter", "YouTube", "Starbucks", "Burger King",
      "Lego", "PlayStation", "Xbox", "Nintendo", "Disney",
    ],

    StirnratenCategory.nineties: [
      "Gameboy", "Tamagotchi", "Backstreet Boys", "Titanic", "Diddl-Maus",
      "VHS-Kassette", "Walkman", "Spice Girls", "Friends", "Der Prinz von Bel-Air",
      "Michael Jackson", "Britney Spears", "Nokia", "Windows 95", "Furby",
      "Macarena", "Bravo Hits", "Loveparade", "G-Shock", "Buffalo Schuhe",
      "Arschgeweih", "D-Mark", "Wiedervereinigung", "Eurodance", "Boybands",
    ],

    StirnratenCategory.twoThousands: [
      "Pokémon Karten", "Nokia 3310", "Britney Spears", "Harry Potter", "MP3-Player",
      "Eminem", "50 Cent", "Beyoncé", "Rihanna", "Lady Gaga",
      "Avatar", "Der Herr der Ringe", "Fluch der Karibik", "Shrek", "Findet Nemo",
      "Facebook", "YouTube", "iPhone", "Wii", "PlayStation 2",
      "Tokio Hotel", "Aggro Berlin", "Sido", "Bushido", "Jamba Sparabo",
    ],

    StirnratenCategory.history: [
      "Albert Einstein", "Kleopatra", "Napoleon", "Mozart", "Leonardo da Vinci",
      "Julius Cäsar", "Alexander der Große", "Kolumbus", "Martin Luther", "Goethe",
      "Schiller", "Beethoven", "Bach", "Van Gogh", "Picasso",
      "Shakespeare", "Darwin", "Newton", "Galileo", "Edison",
      "Tesla", "Curie", "Gandhi", "Mandela", "Luther King",
    ],

    StirnratenCategory.pantomime: [
      "Zähneputzen", "Autofahren", "Schwimmen", "Kochen", "Angeln",
      "Bügeln", "Staubsaugen", "Haare waschen", "Schlafen", "Essen",
      "Trinken", "Telefonieren", "Schreiben", "Lesen", "Malen",
      "Tanzen", "Singen", "Lachen", "Weinen", "Niesen",
      "Husten", "Klatschen", "Winken", "Zeigen", "Springen",
    ],

    StirnratenCategory.noises: [
      "Hubschrauber", "Kuh", "Wecker", "Kettensäge", "Baby",
      "Hund", "Katze", "Schwein", "Pferd", "Schaf",
      "Huhn", "Ente", "Frosch", "Löwe", "Elefant",
      "Auto", "Motorrad", "Zug", "Flugzeug", "Sirene",
      "Klingel", "Telefon", "Tastatur", "Wasserhahn", "Föhn",
    ],

    StirnratenCategory.household: [
      "Toaster", "Staubsauger", "Gabel", "Fernbedienung", "Klobürste",
      "Löffel", "Messer", "Teller", "Tasse", "Glas",
      "Pfanne", "Topf", "Herd", "Backofen", "Kühlschrank",
      "Waschmaschine", "Trockner", "Bügeleisen", "Föhn", "Zahnbürste",
      "Seife", "Handtuch", "Bett", "Kissen", "Decke",
    ],

    StirnratenCategory.bodyParts: [
      "Herz", "Ellenbogen", "Gehirn", "Blinddarm", "Zunge",
      "Auge", "Ohr", "Nase", "Mund", "Zahn",
      "Hals", "Schulter", "Arm", "Hand", "Finger",
      "Bauch", "Rücken", "Bein", "Knie", "Fuß",
      "Zeh", "Haare", "Haut", "Knochen", "Muskel",
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

    StirnratenCategory.books: [
      "Harry Potter", "Der Herr der Ringe", "Die Tribute von Panem", "Twilight", "Der kleine Prinz",
      "Pippi Langstrumpf", "Die unendliche Geschichte", "Momo", "Tintenherz", "Eragon",
      "Gregs Tagebuch", "Die drei ???", "TKKG", "Fünf Freunde", "Hanni und Nanni",
      "Das Parfum", "Der Vorleser", "Faust", "Die Verwandlung", "Im Westen nichts Neues",
      "1984", "Schöne neue Welt", "Der Alchimist", "Der Da Vinci Code", "Illuminati",
    ],

    StirnratenCategory.cities: [
      "Berlin", "München", "Hamburg", "Köln", "Frankfurt",
      "Paris", "London", "New York", "Tokio", "Rom",
      "Barcelona", "Madrid", "Wien", "Zürich", "Amsterdam",
      "Dubai", "Sydney", "Los Angeles", "San Francisco", "Las Vegas",
      "Rio de Janeiro", "Moskau", "Peking", "Istanbul", "Kairo",
    ],

    StirnratenCategory.festivals: [
      "Weihnachten", "Ostern", "Silvester", "Halloween", "Karneval",
      "Oktoberfest", "Valentinstag", "Muttertag", "Vatertag", "Geburtstag",
      "Hochzeit", "Taufe", "Einschulung", "Abschlussball", "Junggesellenabschied",
      "St. Martin", "Nikolaus", "Erntedankfest", "Pfingsten", "Himmelfahrt",
      "Ramadan", "Zuckerfest", "Chanukka", "Diwali", "Thanksgiving",
    ],

    StirnratenCategory.feelings: [
      "Liebe", "Hass", "Wut", "Trauer", "Freude",
      "Angst", "Eifersucht", "Neid", "Stolz", "Scham",
      "Schuld", "Hoffnung", "Verzweiflung", "Einsamkeit", "Langeweile",
      "Aufregung", "Nervosität", "Enttäuschung", "Dankbarkeit", "Mitleid",
      "Sympathie", "Antipathie", "Vertrauen", "Misstrauen", "Gier",
    ],
  };

  static List<String> getWords(StirnratenCategory category) {
    return words[category] ?? [];
  }
}
