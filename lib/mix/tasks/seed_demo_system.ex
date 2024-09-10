if Enum.member?([:dev, :test], Mix.env()) do
  defmodule Mix.Tasks.SeedDemoSystem do
    @moduledoc """
    Seed a couple of demo account to a system for demo and development purposes.
    """

    use Mix.Task
    alias Animina.Accounts.Photo
    alias Animina.Accounts.Role
    alias Animina.Accounts.User
    alias Animina.Accounts.UserRole
    alias Animina.Narratives.Headline
    alias Animina.Narratives.Story
    alias Animina.Traits.Flag
    alias Animina.Traits.UserFlags
    alias Faker.Phone

    require Ash.Query

    def run(_args) do
      # Disable ML features to speed up the seeding process
      System.put_env("DISABLE_ML_FEATURES", "true")

      Mix.Task.run("app.start", [])

      generate_demo_data()

      # Print a list of users
      User.read!()
      |> print_table()
    end

    def generate_demo_data do
      IO.puts("Seeding demo data...")

      raw_seed_data = [
        %{
          unsplash_photo_id: "photo-1531123897727-8f129e1688ce",
          gender: "female",
          about_me:
            "I'm a passionate traveler and foodie. I love exploring new cultures and trying out exotic cuisines. When I'm not traveling, you can find me reading a good book or practicing yoga. My ultimate goal is to visit every continent and learn at least one dish from each country I visit. I believe that travel broadens the mind and enriches the soul, and I enjoy sharing my experiences with others through my travel blog.",
          favorite_travel_story:
            "One of my most unforgettable travel experiences was exploring the bustling markets of Marrakech. The vibrant colors, the fragrant spices, and the lively atmosphere were enchanting. I spent hours wandering through the narrow alleys, trying different street foods, and bargaining with local vendors. The highlight of the trip was a hot air balloon ride over the desert at sunrise, witnessing the golden dunes and the serene landscape from above. It was a magical experience that I'll cherish forever.",
          occupation: nil,
          my_idea_of_a_perfect_day:
            "Waking up in a cozy beachside cottage, enjoying a leisurely breakfast with fresh fruits and pastries, followed by a day of exploring a charming coastal town, trying local delicacies, and ending the day with a peaceful sunset walk along the shore.",
          a_book_that_changed_my_perspective:
            "Eat, Pray, Love by Elizabeth Gilbert – This book opened my eyes to the transformative power of travel and self-discovery, and it inspired me to embrace new experiences with an open heart."
        },
        %{
          unsplash_photo_id: "photo-1526080652727-5b77f74eacd2",
          gender: "female",
          about_me:
            "As a software developer by day and a painter by night, I find joy in both logic and creativity. I enjoy hiking on weekends and volunteering at animal shelters. My paintings are often inspired by the beauty I see during my hikes, and I love creating art that captures the essence of nature. Volunteering at animal shelters brings me immense joy, as I believe in giving back to the community and helping animals in need.",
          favorite_travel_story:
            "My favorite travel memory is hiking through the Swiss Alps. The breathtaking scenery, the fresh mountain air, and the sense of accomplishment when reaching the summit were incredible. Along the way, I encountered charming mountain villages, serene lakes, and friendly locals who shared their stories and traditions. One evening, I painted the sunset over the Alps, capturing the stunning beauty and tranquility of the moment. It was a perfect blend of adventure and creativity.",
          occupation: "Software Developer",
          my_idea_of_a_perfect_day:
            "Spending the morning hiking through a serene forest, painting a landscape inspired by the hike in the afternoon, and then relaxing at home with a good book and a cup of tea.",
          a_book_that_changed_my_perspective:
            "The Alchemist by Paulo Coelho – This book taught me the importance of pursuing one’s personal legend and the power of dreams and persistence."
        },
        %{
          unsplash_photo_id: "photo-1598897516650-e4dc73d8e417",
          gender: "female",
          about_me:
            "Music is my life! I play the guitar and love attending live concerts. I also enjoy baking and often experiment with new dessert recipes. There's something magical about creating music and sharing it with others, and I hope to someday perform in front of a large audience. Baking is my therapy, and I find peace in the process of mixing ingredients and creating delicious treats for my loved ones.",
          favorite_travel_story:
            "Attending a music festival in Barcelona was a dream come true. The city was alive with music, and the energy was infectious. I spent my days exploring the city's vibrant culture, indulging in delicious tapas, and my nights dancing to live performances by my favorite bands. One evening, I joined a group of local musicians for an impromptu jam session on the beach, under the stars. It was a magical experience that ignited my passion for music even further.",
          occupation: nil,
          my_idea_of_a_perfect_day:
            "Attending a live music concert with friends, followed by an evening of jamming on the guitar at a cozy outdoor café.",
          a_book_that_changed_my_perspective:
            "Just Kids by Patti Smith – This memoir deepened my appreciation for the intersection of art, music, and life, and it inspired me to pursue my creative passions with dedication."
        },
        %{
          unsplash_photo_id: "photo-1536896407451-6e3dd976edd1",
          gender: "female",
          about_me:
            "I'm an avid runner and have completed several marathons. I love the thrill of pushing my limits. In my downtime, I enjoy binge-watching mystery series and gardening. Running has taught me the importance of perseverance and discipline, and it keeps me motivated to achieve my goals. Gardening is my way of connecting with nature and finding tranquility amidst the hustle and bustle of life.",
          favorite_travel_story:
            "Running the Great Wall Marathon in China was a once-in-a-lifetime experience. The challenging course, with its steep steps and breathtaking views, pushed me to my limits both physically and mentally. As I crossed the finish line, surrounded by fellow runners from around the world, I felt an overwhelming sense of accomplishment. It was a humbling reminder of the power of perseverance and the beauty of human resilience.",
          occupation: nil,
          my_idea_of_a_perfect_day:
            "Starting the day with a refreshing morning run, followed by brunch with friends, and spending the afternoon gardening or watching a mystery series.",
          a_book_that_changed_my_perspective:
            "Born to Run by Christopher McDougall – This book transformed my understanding of running, showing me how it can be a joyful and liberating experience."
        },
        %{
          unsplash_photo_id: "photo-1499399244875-59ef3e1347e3",
          gender: "female",
          about_me:
            "I'm a nature enthusiast and spend most of my free time in the great outdoors. Hiking, camping, and bird watching are some of my favorite activities. I also enjoy photography and capturing the beauty of nature. My dream is to travel to all the national parks and document my journey through photographs and journals. There's something truly magical about being in the wild and experiencing nature in its purest form.",
          favorite_travel_story:
            "Exploring the rugged landscapes of Iceland was a surreal experience. From majestic waterfalls to sprawling glaciers, every corner of the island felt like a scene from a fantasy novel. I spent my days hiking through volcanic landscapes, soaking in hot springs, and chasing the elusive Northern Lights. One night, as I lay under a blanket of stars, watching the aurora dance across the sky, I felt a profound connection to the earth and the universe. It was a journey of self-discovery and wonder that will stay with me forever.",
          occupation: "Nature Photographer",
          my_idea_of_a_perfect_day:
            "Waking up early to catch the sunrise over a beautiful landscape, spending the day hiking and photographing nature, and ending with a peaceful evening campfire under the stars.",
          a_book_that_changed_my_perspective:
            "Into the Wild by Jon Krakauer – This book challenged my views on materialism and inspired me to seek deeper connections with nature."
        },
        %{
          unsplash_photo_id: "photo-1484608856193-968d2be4080e",
          gender: "female",
          about_me:
            "A history buff and a museum lover, I enjoy learning about different cultures and eras. I also love cooking and often host dinner parties for my friends. Exploring ancient ruins and visiting historical landmarks is my way of traveling back in time and understanding the world's rich history. Cooking is my way of expressing creativity, and I find joy in experimenting with different cuisines and flavors.",
          favorite_travel_story:
            "Visiting the ancient city of Petra in Jordan was like stepping into a time machine. Walking through the narrow Siq, flanked by towering sandstone cliffs, I felt a sense of awe and wonder. As I emerged from the canyon, the Treasury came into view, bathed in the golden light of dawn. I spent hours exploring the intricately carved facades and hidden tombs, marveling at the ingenuity of the Nabateans. It was a journey through history that left me humbled and inspired.",
          occupation: nil,
          my_idea_of_a_perfect_day:
            "Visiting a historical site or museum in the morning, trying a new recipe in the afternoon, and hosting a dinner party with friends in the evening.",
          a_book_that_changed_my_perspective:
            "Sapiens by Yuval Noah Harari – This book profoundly changed my understanding of human history and our place in the world."
        },
        %{
          unsplash_photo_id: "photo-1502768040783-423da5fd5fa0",
          gender: "female",
          about_me:
            "I work as a graphic designer and have a keen eye for detail. I love visiting art galleries and attending creative workshops. My weekends are usually spent cycling around the city. Design is my passion, and I find inspiration in everyday life, whether it's the architecture of buildings or the colors of a sunset. Cycling helps me clear my mind and stay fit while exploring the urban landscape.",
          favorite_travel_story:
            "Exploring the streets of Tokyo during cherry blossom season was a dream come true. The city was transformed into a sea of pink, and the cherry blossoms painted a picture of pure beauty. I spent my days wandering through the parks, admiring the delicate flowers, and tasting traditional Japanese snacks from street vendors. One evening, I visited a traditional tea house and participated in a tea ceremony, experiencing the serene elegance of Japanese culture. It was a magical journey that awakened all my senses and left me longing for more.",
          occupation: "Graphic Designer",
          my_idea_of_a_perfect_day:
            "Cycling through the city in the morning, visiting an art gallery in the afternoon, and ending the day with a creative workshop or designing something new.",
          a_book_that_changed_my_perspective:
            "The Design of Everyday Things by Don Norman – This book revolutionized my approach to design, making me focus on user-centered design principles."
        },
        %{
          unsplash_photo_id: "photo-1465406325903-9d93ee82f613",
          gender: "female",
          about_me:
            "I'm a fitness trainer and a health nut. I love helping people achieve their fitness goals. When I'm not at the gym, I enjoy reading about nutrition and wellness. Fitness is my way of life, and I believe in the power of a healthy body and mind. I enjoy sharing my knowledge with others and motivating them to lead healthier, happier lives. In my spare time, I experiment with new healthy recipes and stay updated with the latest in fitness science.",
          favorite_travel_story:
            "Trekking through the Himalayas was an adventure of a lifetime. The majestic mountains, the crisp mountain air, and the warm hospitality of the locals made it an unforgettable experience. I hiked through remote villages, crossed suspension bridges over raging rivers, and gazed in awe at snow-capped peaks. One evening, I sat by a roaring bonfire, surrounded by fellow trekkers, sharing stories and laughter under the starlit sky. It was a journey that tested my limits and filled my heart with gratitude for the beauty of nature and the kindness of strangers.",
          occupation: "Fitness Trainer",
          my_idea_of_a_perfect_day:
            "Starting the day with an intense workout session, followed by a nutritious brunch, and spending the rest of the day outdoors, either hiking or enjoying a yoga session in nature.",
          a_book_that_changed_my_perspective:
            "The Blue Zones by Dan Buettner – This book opened my eyes to the habits that lead to a longer, healthier life, inspiring me to incorporate them into my fitness philosophy."
        },
        %{
          unsplash_photo_id: "photo-1542596594-649edbc13630",
          gender: "female",
          about_me:
            "I have a passion for fashion and work as a stylist. I enjoy experimenting with different looks and keeping up with the latest trends. In my spare time, I like to unwind with a good movie or a night out with friends. Fashion is not just a career for me; it's a way of expressing myself and making a statement. I love helping people find their style and feel confident in their own skin.",
          favorite_travel_story:
            "Exploring the ancient ruins of Machu Picchu was like stepping back in time. As I walked along the ancient stone paths, surrounded by towering peaks and lush greenery, I felt a sense of wonder and reverence for the Inca civilization. I climbed to the Sun Gate at dawn, watching the sun rise over the sacred citadel and illuminating the mystical landscape below. One evening, I joined a group of travelers for a traditional Pachamanca feast, savoring the flavors of Andean cuisine and sharing stories of our adventures. It was a journey that filled me with awe and gratitude for the rich tapestry of human history and culture.",
          occupation: "Stylist",
          my_idea_of_a_perfect_day:
            "Browsing through fashion boutiques in the morning, experimenting with new looks in the afternoon, and spending the evening at a stylish rooftop bar with friends.",
          a_book_that_changed_my_perspective:
            "The Fashion System by Roland Barthes – This book deepened my understanding of the cultural significance of fashion and its impact on society."
        },
        %{
          unsplash_photo_id: "photo-1520466809213-7b9a56adcd45",
          gender: "female",
          about_me:
            "I'm a scientist with a love for the stars. Astronomy fascinates me, and I spend many nights stargazing. I also enjoy playing chess and solving puzzles. Science is my calling, and I love unraveling the mysteries of the universe. Stargazing is my way of connecting with the cosmos and pondering our place in the vast expanse. Chess and puzzles keep my mind sharp and challenge me to think critically.",
          favorite_travel_story:
            "Sailing through the Greek islands was a blissful escape from reality. The turquoise waters, the whitewashed villages, and the warm Mediterranean sun created a postcard-perfect backdrop for adventure. I island-hopped from one paradise to another, exploring ancient ruins, swimming in secluded coves, and savoring delicious Greek cuisine. One evening, I watched the sunset from the deck of my sailboat, surrounded by friends and laughter, feeling truly alive and free. It was a journey of discovery and joy that rejuvenated my spirit and left me yearning for more.",
          occupation: "Scientist",
          my_idea_of_a_perfect_day:
            "Spending the day at an observatory stargazing and discussing astronomy with fellow enthusiasts, and unwinding in the evening with a challenging puzzle or a game of chess.",
          a_book_that_changed_my_perspective:
            "A Brief History of Time by Stephen Hawking – This book expanded my understanding of the universe and deepened my fascination with the mysteries of space."
        },
        %{
          unsplash_photo_id: "photo-1580489944761-15a19d654956",
          gender: "female",
          about_me:
            "I run a small bakery and love creating new recipes. My dream is to open a chain of bakeries someday. In my free time, I enjoy knitting and reading romantic novels. Baking is my passion, and I find joy in seeing people smile when they taste my creations. Knitting helps me relax, and I love crafting handmade gifts for my loved ones. Reading romantic novels transports me to a world of love and adventure, fueling my creativity.",
          favorite_travel_story:
            "Immersing myself in the vibrant culture of India was a transformative experience. From the bustling streets of Delhi to the tranquil backwaters of Kerala, every moment was filled with color, chaos, and beauty. I explored ancient temples, tasted exotic spices, and danced to the rhythm of traditional music. One evening, I attended a Diwali celebration, witnessing the spectacle of lights and joining in the festivities with locals and fellow travelers. It was a journey of contrasts and contradictions that challenged my perceptions and enriched my soul.",
          occupation: "Baker",
          my_idea_of_a_perfect_day:
            "Starting the day by baking a new recipe, spending the afternoon knitting or reading a romantic novel, and hosting a cozy evening tea party with friends.",
          a_book_that_changed_my_perspective:
            "Like Water for Chocolate by Laura Esquivel – This book made me realize the deep emotional connections that can be made through food and inspired me to create dishes with love and care."
        },
        %{
          unsplash_photo_id: "photo-1567532939604-b6b5b0db2604",
          gender: "female",
          about_me:
            "As a teacher, I find joy in shaping young minds. I love working with children and making learning fun. My hobbies include playing the piano and gardening. Teaching is my calling, and I believe in the power of education to change lives. I strive to create a positive and engaging learning environment for my students. Playing the piano helps me unwind, and gardening allows me to nurture life and witness the beauty of growth.",
          favorite_travel_story:
            "Embarking on a safari in the Serengeti was like stepping into a wildlife documentary. The vast savannahs, the towering acacia trees, and the diverse wildlife made it an unforgettable adventure. I witnessed the Great Migration, with herds of wildebeest and zebra stretching as far as the eye could see. I also encountered majestic lions, graceful giraffes, and elusive cheetahs on game drives. One evening, I sat by a campfire under the stars, listening to the sounds of the African bush and feeling a deep connection to the natural world. It was a journey of awe and wonder that left me humbled by the beauty and resilience of the animal kingdom.",
          occupation: "Teacher",
          my_idea_of_a_perfect_day:
            "Teaching a fun and engaging lesson in the morning, playing the piano in the afternoon, and spending the evening gardening or reading a good book.",
          a_book_that_changed_my_perspective:
            "To Kill a Mockingbird by Harper Lee – This book deepened my understanding of empathy and the importance of standing up for what is right, which I strive to teach my students."
        },
        %{
          unsplash_photo_id: "photo-1505640070685-2a70292000ff",
          gender: "male",
          about_me:
            "As an engineer, I find satisfaction in solving complex problems and bringing innovative ideas to life. I enjoy working with technology and constantly learning about new advancements. My hobbies include cycling and woodworking. Engineering is my passion, and I believe in the impact of technology on improving lives. I strive to create efficient and sustainable solutions in my projects. Cycling helps me stay fit and clear my mind, while woodworking allows me to create tangible and functional pieces.",
          favorite_travel_story:
            "Exploring the Swiss Alps was a breathtaking experience. The stunning mountain scenery, pristine lakes, and charming villages made it a memorable trip. I hiked through picturesque trails, taking in the fresh alpine air and the spectacular views. One morning, I reached the summit of a peak just in time to see the sunrise, painting the sky with vibrant colors. I also had the opportunity to try paragliding, soaring above the valleys and feeling an exhilarating sense of freedom. The trip was a perfect blend of adventure and tranquility, leaving me with lasting memories of the beauty and majesty of the Swiss Alps.",
          occupation: "Engineer",
          my_idea_of_a_perfect_day:
            "Cycling through scenic trails in the morning, working on a personal engineering project in the afternoon, and unwinding in the evening by woodworking.",
          a_book_that_changed_my_perspective:
            "The Innovator's Dilemma by Clayton M. Christensen – This book fundamentally changed the way I approach innovation and technology, helping me understand the challenges and opportunities of disruptive innovation."
        },
        %{
          unsplash_photo_id: "photo-1557862921-37829c790f19",
          gender: "male",
          about_me:
            "As a doctor, I am dedicated to improving the health and well-being of my patients. I enjoy the challenges and rewards that come with the medical profession. My hobbies include running and cooking. Medicine is not just a career for me, but a calling. I believe in providing compassionate care and staying updated with the latest medical advancements. Running helps me stay fit and focused, while cooking allows me to relax and experiment with new recipes.",
          favorite_travel_story:
            "Traveling to Japan was an incredible journey of cultural discovery and culinary delights. From the bustling streets of Tokyo to the serene temples of Kyoto, every moment was filled with wonder. I marveled at the cherry blossoms in full bloom and savored authentic sushi prepared by skilled chefs. One evening, I participated in a traditional tea ceremony, experiencing the grace and precision of this ancient practice. The trip was a perfect blend of modern and traditional experiences, leaving me with a deep appreciation for Japan's rich heritage and vibrant culture.",
          occupation: "Doctor",
          my_idea_of_a_perfect_day:
            "Starting the day with a brisk morning run, spending the afternoon cooking a new recipe, and relaxing in the evening with a good book or a movie.",
          a_book_that_changed_my_perspective:
            "The Emperor of All Maladies by Siddhartha Mukherjee – This biography of cancer gave me a deeper understanding of the disease and the history of its treatment, reinforcing my commitment to medicine."
        },
        %{
          unsplash_photo_id: "photo-1702449269565-8bbe32972f65",
          gender: "male",
          about_me:
            "As a software developer, I thrive on the creativity and logic required to build innovative solutions. I enjoy coding, learning new programming languages, and keeping up with technology trends. My hobbies include playing chess and hiking. Software development allows me to turn ideas into reality, and I believe in the power of technology to solve real-world problems. Playing chess sharpens my strategic thinking, while hiking provides me with an escape into nature and a chance to recharge.",
          favorite_travel_story:
            "Hiking the trails of Patagonia was an adventure like no other. The rugged landscapes, towering mountains, and glacial lakes created a stunning backdrop for my journey. I trekked through diverse terrains, from dense forests to open plains, each day bringing new challenges and breathtaking views. One memorable day, I reached the base of the iconic Torres del Paine, where the sheer rock towers soared into the sky. Camping under the stars in this remote wilderness, I felt a profound connection to the natural world. The experience was a testament to the raw beauty and untamed spirit of Patagonia.",
          occupation: "Software Developer",
          my_idea_of_a_perfect_day:
            "Coding in the morning while sipping coffee, going for a hike in the afternoon, and ending the day with a chess match or learning a new programming language.",
          a_book_that_changed_my_perspective:
            "Clean Code by Robert C. Martin – This book revolutionized the way I write and approach code, emphasizing the importance of writing clean, maintainable software."
        },
        %{
          unsplash_photo_id: "photo-1700856417754-cb66c909f4d7",
          gender: "male",
          about_me:
            "As a chef, I am passionate about creating delicious and innovative dishes. I enjoy experimenting with flavors and ingredients to surprise and delight my guests. My hobbies include painting and cycling. Cooking is an art for me, and I believe in the joy that good food can bring to people's lives. Painting allows me to express my creativity, while cycling helps me stay active and explore new places.",
          favorite_travel_story:
            "Exploring the vibrant markets and rich culinary heritage of Morocco was an unforgettable experience. From the bustling streets of Marrakech to the tranquil desert landscapes, every moment was a feast for the senses. I savored traditional dishes like tagine and couscous, learning from local chefs and discovering new ingredients. One evening, I joined a Berber family for dinner in the Sahara, sharing stories and enjoying a meal under the starry sky. The trip was a culinary adventure that deepened my appreciation for the diverse flavors and traditions of Moroccan cuisine.",
          occupation: "Chef",
          my_idea_of_a_perfect_day:
            "Visiting a farmer's market in the morning, experimenting with new recipes in the afternoon, and ending the day with a quiet evening painting or cycling.",
          a_book_that_changed_my_perspective:
            "Kitchen Confidential by Anthony Bourdain – This book provided a raw and unfiltered look at the culinary world, changing how I viewed the restaurant industry and my role as a chef."
        },
        %{
          unsplash_photo_id: "photo-1627837661889-6fc9434e12f6",
          gender: "male",
          about_me:
            "As a journalist, I am dedicated to uncovering the truth and telling compelling stories. I enjoy investigating important issues and giving a voice to those who are often unheard. My hobbies include reading and photography. Journalism is my way of making a difference in the world, and I believe in the power of a well-told story to inspire change. Reading helps me stay informed, while photography allows me to capture moments and tell visual stories.",
          favorite_travel_story:
            "Covering the vibrant culture and history of India was an eye-opening experience. From the bustling cities to the serene countryside, I encountered a wealth of stories waiting to be told. I visited ancient temples, bustling markets, and rural villages, each offering a unique perspective on Indian life. One unforgettable moment was attending the Kumbh Mela, a massive religious festival, where millions gathered to take a holy dip in the Ganges. The trip was a journey through time and culture, providing a deeper understanding of the complexities and beauty of India.",
          occupation: "Journalist",
          my_idea_of_a_perfect_day:
            "Spending the morning reading and researching a new story, taking photographs in the afternoon, and writing a compelling article in the evening.",
          a_book_that_changed_my_perspective:
            "The Elements of Journalism by Bill Kovach and Tom Rosenstiel – This book reinforced my commitment to journalistic principles and the importance of truth in reporting."
        },
        %{
          unsplash_photo_id: "photo-1677759337999-ceae7a0a5faa",
          gender: "male",
          about_me:
            "As a musician, I find joy in creating and performing music that resonates with people. I enjoy exploring different genres and collaborating with other artists. My hobbies include traveling and learning new languages. Music is my universal language, and I believe in its ability to bring people together. Traveling inspires my creativity, while learning languages helps me connect with diverse cultures and audiences.",
          favorite_travel_story:
            "Touring through Europe with my band was an exhilarating experience. From the historic venues of London to the lively streets of Barcelona, each city had its own unique rhythm. We played in iconic locations, met amazing fans, and soaked in the local cultures. One memorable night, we performed at a small club in Berlin, where the energy of the crowd was electric, and the music flowed effortlessly. The tour was a whirlwind of music, adventure, and unforgettable moments, leaving me with a deep appreciation for the diverse sounds and stories of Europe.",
          occupation: "Musician",
          my_idea_of_a_perfect_day:
            "Practicing new music in the morning, recording in the studio in the afternoon, and performing live in the evening, followed by a jam session with fellow musicians.",
          a_book_that_changed_my_perspective:
            "This Is Your Brain on Music by Daniel J. Levitin – This book changed the way I understand the science behind music and its profound effect on the human brain."
        },
        %{
          unsplash_photo_id: "photo-1707139743543-590aeb0437d8",
          gender: "male",
          about_me:
            "As an architect, I am passionate about designing spaces that are both functional and beautiful. I enjoy the challenge of bringing creative visions to life and improving the environments where people live and work. My hobbies include photography and hiking. Architecture allows me to blend art and science, and I believe in the transformative power of good design. Photography helps me see the world from different perspectives, while hiking provides inspiration from nature.",
          favorite_travel_story:
            "Exploring the architectural wonders of Italy was a dream come true. From the ancient ruins of Rome to the Renaissance masterpieces of Florence, every site was a testament to human creativity and ingenuity. I marveled at the intricate details of the Colosseum, the grandeur of the Vatican, and the elegance of the Duomo. One evening, I watched the sunset from Piazzale Michelangelo, overlooking the city of Florence bathed in golden light. The trip was a journey through history and art, deepening my appreciation for the enduring legacy of Italian architecture.",
          occupation: "Architect",
          my_idea_of_a_perfect_day:
            "Visiting a new architectural site in the morning, sketching designs in the afternoon, and spending the evening photographing cityscapes during sunset.",
          a_book_that_changed_my_perspective:
            "The Fountainhead by Ayn Rand – This novel challenged my ideas about creativity, individualism, and the role of an architect in society."
        },
        %{
          unsplash_photo_id: "photo-1506794778202-cad84cf45f1d",
          gender: "male",
          about_me:
            "As a scientist, I am driven by curiosity and the desire to understand the natural world. I enjoy conducting experiments, analyzing data, and discovering new phenomena. My hobbies include stargazing and playing the guitar. Science is my way of making sense of the universe, and I believe in the importance of research and innovation. Stargazing fuels my sense of wonder, while playing the guitar helps me relax and express myself creatively.",
          favorite_travel_story:
            "Visiting the observatories of Hawaii was an awe-inspiring experience. The clear skies and advanced telescopes provided unparalleled views of the cosmos. I spent nights observing distant galaxies, nebulae, and star clusters, feeling a profound connection to the universe. One memorable night, I witnessed a meteor shower from the summit of Mauna Kea, the shooting stars streaking across the sky in a dazzling display. The trip was a blend of scientific discovery and natural beauty, leaving me with a deeper appreciation for the mysteries of the night sky.",
          occupation: "Scientist",
          my_idea_of_a_perfect_day:
            "Conducting experiments or research in the morning, stargazing at an observatory in the afternoon, and playing the guitar to unwind in the evening.",
          a_book_that_changed_my_perspective:
            "The Selfish Gene by Richard Dawkins – This book fundamentally changed my understanding of evolution and the role of genetics in shaping behavior."
        },
        %{
          unsplash_photo_id: "photo-1531891570158-e71b35a485bc",
          gender: "male",
          about_me:
            "As a pilot, I find exhilaration in soaring through the skies and experiencing the world from above. I enjoy navigating complex airspaces and ensuring the safety of my passengers. My hobbies include skydiving and scuba diving. Aviation is my passion, and I believe in the freedom and adventure that flying brings. Skydiving pushes my limits, while scuba diving allows me to explore the mysteries of the underwater world.",
          favorite_travel_story:
            "Flying to the remote islands of the Maldives was a breathtaking adventure. The crystal-clear waters, pristine beaches, and vibrant marine life made it a paradise on earth. I piloted a seaplane, giving me a bird’s-eye view of the stunning atolls and coral reefs. One day, I landed on a secluded island where I spent the afternoon snorkeling among colorful fish and corals. The trip was a perfect blend of aerial and underwater exploration, leaving me with unforgettable memories of the natural beauty of the Maldives.",
          occupation: "Pilot",
          my_idea_of_a_perfect_day:
            "Flying to a remote and scenic location in the morning, spending the afternoon skydiving or scuba diving, and ending the day relaxing on a quiet beach.",
          a_book_that_changed_my_perspective:
            "West with the Night by Beryl Markham – This memoir of an aviator’s life during the early days of flight inspired me to pursue a career in aviation and to embrace the spirit of adventure."
        },
        %{
          unsplash_photo_id: "photo-1582015752624-e8b1c75e3711",
          gender: "male",
          about_me:
            "As a historian, I am fascinated by the stories and events that have shaped our world. I enjoy researching, writing, and teaching about history. My hobbies include visiting museums and collecting rare books. History is my passion, and I believe in preserving the past to understand the present and future. Visiting museums enriches my knowledge, while collecting rare books connects me to the historical periods I study.",
          favorite_travel_story:
            "Exploring the ancient ruins of Greece was a journey through time. Walking through the remnants of ancient civilizations, from the Acropolis in Athens to the ruins of Delphi, I felt a deep connection to the past. One highlight was standing in the shadow of the Parthenon, imagining the grandeur of ancient Athens. Another unforgettable moment was sailing to the island of Santorini, where the sunset over the caldera painted the sky in brilliant hues. The trip was a captivating blend of history and natural beauty, deepening my appreciation for the legacy of ancient Greece.",
          occupation: "Historian",
          my_idea_of_a_perfect_day:
            "Spending the morning visiting historical sites or museums, reading rare books in the afternoon, and discussing history over dinner with fellow enthusiasts.",
          a_book_that_changed_my_perspective:
            "Guns, Germs, and Steel by Jared Diamond – This book offered a groundbreaking perspective on the factors that shaped human history, profoundly influencing my approach to historical research."
        },
        %{
          unsplash_photo_id: "photo-1525393839361-867d646aea41",
          gender: "male",
          about_me:
            "As a wildlife photographer, I am passionate about capturing the beauty and diversity of the natural world. I enjoy traveling to remote locations and patiently waiting for the perfect shot. My hobbies include birdwatching and hiking. Photography allows me to share the wonders of nature with others, and I believe in the importance of conservation. Birdwatching helps me appreciate the avian world, while hiking takes me to breathtaking landscapes.",
          favorite_travel_story:
            "Photographing the wildlife in the Amazon rainforest was an extraordinary experience. The dense jungle, teeming with life, offered endless opportunities for stunning shots. I encountered exotic birds, playful monkeys, and elusive jaguars, each moment a testament to the richness of the ecosystem. One morning, I captured a pair of vibrant macaws in flight, their colors vivid against the lush green backdrop. The trip was a challenging yet rewarding adventure, leaving me with a deep respect for the beauty and complexity of the Amazon rainforest.",
          occupation: "Wildlife Photographer",
          my_idea_of_a_perfect_day:
            "Waking up early for a wildlife photography session, spending the day exploring a natural reserve, and editing photos in the evening with a cup of tea.",
          a_book_that_changed_my_perspective:
            "The Sixth Extinction by Elizabeth Kolbert – This book heightened my awareness of the ongoing biodiversity crisis and strengthened my commitment to conservation through photography."
        },
        %{
          unsplash_photo_id: "photo-1614647444531-ac308ea848eb",
          gender: "male",
          about_me:
            "As a marine biologist, I am dedicated to studying and protecting marine life. I enjoy conducting research, diving, and exploring underwater ecosystems. My hobbies include sailing and underwater photography. Marine biology is my calling, and I believe in the importance of preserving our oceans. Sailing connects me to the marine environment, while underwater photography allows me to document the incredible diversity beneath the waves.",
          favorite_travel_story:
            "Researching coral reefs in the Great Barrier Reef was a once-in-a-lifetime experience. The vibrant corals, diverse marine species, and crystal-clear waters made it an underwater paradise. I spent days diving and collecting data, observing the intricate relationships within the reef ecosystem. One memorable dive, I swam alongside a gentle giant, a manta ray, its graceful movements mesmerizing. The trip was both a scientific expedition and an awe-inspiring adventure, highlighting the need to protect such fragile and beautiful ecosystems.",
          occupation: "Marine Biologist",
          my_idea_of_a_perfect_day:
            "Diving and conducting research in the morning, sailing in the afternoon, and relaxing with underwater photography in the evening.",
          a_book_that_changed_my_perspective:
            "The Sea Around Us by Rachel Carson – This book deepened my love for the ocean and solidified my commitment to marine conservation."
        },
        %{
          unsplash_photo_id: "photo-1500648767791-00dcc994a43e",
          gender: "male",
          about_me:
            "As a paramedic, I am committed to providing emergency medical care and saving lives. I enjoy the fast-paced nature of my job and the opportunity to help people in critical situations. My hobbies include mountain biking and playing the drums. Being a paramedic is my way of making a difference, and I believe in the importance of quick and compassionate care. Mountain biking keeps me fit and adventurous, while playing the drums helps me unwind and express my rhythm.",
          favorite_travel_story:
            "Volunteering in a medical camp in rural Nepal was a humbling and rewarding experience. The mountainous landscapes, coupled with the warm hospitality of the locals, made it a memorable trip. I provided medical care to communities with limited access to healthcare, learning about their culture and resilience. One day, I hiked to a remote village, carrying supplies and offering treatment to those in need. The trip was a blend of professional dedication and personal growth, leaving me with a deep appreciation for the spirit and strength of the Nepali people.",
          occupation: "Paramedic",
          my_idea_of_a_perfect_day:
            "Starting the day with an intense mountain biking session, spending the afternoon volunteering or helping others, and ending the day playing the drums or listening to music.",
          a_book_that_changed_my_perspective:
            "Mountains Beyond Mountains by Tracy Kidder – This book inspired me to approach my work with the same compassion and dedication as Dr. Paul Farmer, showing the profound impact of medical care in underserved areas."
        }
      ]

      Enum.each(raw_seed_data, fn seed_data ->
        create_demo_user(seed_data)
      end)
    end

    defp create_demo_user(seed_data) do
      first_name = random_first_name(seed_data.gender)
      last_name = Faker.Person.last_name()
      full_name = "#{first_name} #{last_name}"
      height = Enum.take_random(Enum.to_list(160..190), 1) |> hd
      birthday = Faker.Date.date_of_birth(18..40)
      age = (Date.diff(Date.utc_today(), birthday) / 365) |> round

      user =
        User.create!(%{
          email: Faker.Internet.email(),
          username: convert_name_to_username(full_name) |> String.slice(0..14),
          name: full_name,
          zip_code: random_zip_code(),
          language: "DE-de",
          country: "Germany",
          legal_terms_accepted: true,
          gender: seed_data.gender,
          height: height,
          mobile_phone: random_mobile_phone_number(),
          birthday: birthday,
          hashed_password: Bcrypt.hash_pwd_salt("test"),
          occupation: seed_data.occupation,
          minimum_partner_height: height - 30,
          maximum_partner_height: height + 15,
          minimum_partner_age: minimum_partner_age(age),
          maximum_partner_age: age + 10,
          partner_gender: opposite_gender(seed_data.gender),
          search_range: hd(Enum.take_random([5, 10, 20, 50], 1)),
          confirmed_at: DateTime.utc_now()
        })

      user_role = Role.by_name!(:user)

      UserRole.create(%{
        user_id: user.id,
        role_id: user_role.id
      })

      # create profile photo
      photo = download_photo(seed_data.unsplash_photo_id, "#{Faker.UUID.v4()}.png")
      Photo.create!(Map.merge(photo, %{user_id: user.id}))

      # create about me story
      story =
        Story.create!(%{
          headline_id: get_headline_id("About me"),
          user_id: user.id,
          content: seed_data.about_me,
          position: 1
        })

      # create about me story photo
      Photo.create!(Map.merge(photo, %{user_id: user.id, story_id: story.id}))

      unused_photos = all_photos()

      story =
        Story.create!(%{
          headline_id: get_headline_id("The adventure that left me speechless"),
          user_id: user.id,
          content: seed_data.favorite_travel_story,
          position: 2
        })

      {photo, unused_photos} = pick_a_random_photo(unused_photos)

      if photo do
        Photo.create!(Map.merge(photo, %{user_id: user.id, story_id: story.id}))
      end

      story =
        Story.create!(%{
          headline_id: get_headline_id("My idea of a perfect day"),
          user_id: user.id,
          content: seed_data.my_idea_of_a_perfect_day,
          position: 3
        })

      {photo, unused_photos} = pick_a_random_photo(unused_photos)

      if photo do
        Photo.create!(Map.merge(photo, %{user_id: user.id, story_id: story.id}))
      end

      story =
        Story.create!(%{
          headline_id: get_headline_id("A book that changed my perspective"),
          user_id: user.id,
          content: seed_data.a_book_that_changed_my_perspective,
          position: 4
        })

      {photo, _unused_photos} = pick_a_random_photo(unused_photos)

      if photo do
        Photo.create!(Map.merge(photo, %{user_id: user.id, story_id: story.id}))
      end

      Enum.each(1..Enum.random(5..20), fn _i ->
        create_random_flag(user, :white)
      end)

      # create random green flags
      Enum.each(1..Enum.random(5..10), fn _i ->
        create_random_flag(user, :green)
      end)

      # create random red flags
      Enum.each(1..Enum.random(3..10), fn _i ->
        create_random_flag(user, :red)
      end)
    end

    defp random_first_name("female") do
      [
        "Olivia",
        "Emma",
        "Ava",
        "Sophia",
        "Isabella",
        "Charlotte",
        "Amelia",
        "Mia",
        "Harper",
        "Evelyn",
        "Abigail",
        "Emily",
        "Ella",
        "Elizabeth",
        "Camila",
        "Luna",
        "Sofia",
        "Avery",
        "Mila",
        "Aria",
        "Scarlett",
        "Penelope",
        "Layla",
        "Chloe",
        "Victoria",
        "Madison",
        "Eleanor",
        "Grace",
        "Nora",
        "Riley",
        "Zoey",
        "Hannah",
        "Hazel",
        "Lily",
        "Ellie",
        "Violet",
        "Lillian",
        "Zoe",
        "Stella",
        "Aurora",
        "Natalie",
        "Emilia",
        "Everly",
        "Leah",
        "Aubrey",
        "Willow",
        "Addison",
        "Lucy",
        "Audrey",
        "Bella",
        "Nova",
        "Brooklyn",
        "Paisley",
        "Savannah",
        "Claire",
        "Skylar",
        "Isla",
        "Genesis",
        "Naomi",
        "Elena",
        "Caroline",
        "Eliana",
        "Anna",
        "Maya",
        "Valentina",
        "Ruby",
        "Kennedy",
        "Ivy",
        "Ariana",
        "Aaliyah",
        "Cora",
        "Madelyn",
        "Alice",
        "Kinsley",
        "Hailey",
        "Gabriella",
        "Allison",
        "Gianna",
        "Serenity",
        "Samantha",
        "Sarah",
        "Autumn",
        "Quinn",
        "Eva",
        "Piper",
        "Sophie",
        "Sadie",
        "Delilah",
        "Josephine",
        "Nevaeh",
        "Adeline",
        "Arya",
        "Emery",
        "Lydia",
        "Clara",
        "Vivian",
        "Madeline",
        "Peyton",
        "Julia",
        "Rylee"
      ]
      |> Enum.random()
    end

    defp random_first_name("male") do
      [
        "Liam",
        "Noah",
        "Oliver",
        "Elijah",
        "William",
        "James",
        "Benjamin",
        "Lucas",
        "Henry",
        "Alexander",
        "Mason",
        "Michael",
        "Ethan",
        "Daniel",
        "Jacob",
        "Logan",
        "Jackson",
        "Levi",
        "Sebastian",
        "Mateo",
        "Jack",
        "Owen",
        "Theodore",
        "Aiden",
        "Samuel",
        "Joseph",
        "John",
        "David",
        "Wyatt",
        "Matthew",
        "Luke",
        "Asher",
        "Carter",
        "Julian",
        "Grayson",
        "Leo",
        "Jayden",
        "Gabriel",
        "Isaac",
        "Lincoln",
        "Anthony",
        "Hudson",
        "Dylan",
        "Ezra",
        "Thomas",
        "Charles",
        "Christopher",
        "Jaxon",
        "Maverick",
        "Josiah",
        "Isaiah",
        "Andrew",
        "Elias",
        "Joshua",
        "Nathan",
        "Caleb",
        "Ryan",
        "Adrian",
        "Miles",
        "Eli",
        "Nolan",
        "Christian",
        "Aaron",
        "Cameron",
        "Ezekiel",
        "Colton",
        "Luca",
        "Landon",
        "Hunter",
        "Jonathan",
        "Santiago",
        "Axel",
        "Easton",
        "Cooper",
        "Jeremiah",
        "Angel",
        "Roman",
        "Connor",
        "Jameson",
        "Robert",
        "Greyson",
        "Jordan",
        "Ian",
        "Carson",
        "Jaxson",
        "Leonardo",
        "Nicholas",
        "Dominic",
        "Austin",
        "Everett",
        "Brooks",
        "Xavier",
        "Kai",
        "Jose",
        "Parker",
        "Adam",
        "Jace",
        "Wesley",
        "Kayden",
        "Silas",
        "Bennett"
      ]
      |> Enum.random()
    end

    defp convert_name_to_username(name) do
      name
      |> String.replace(~r/Mrs. /, "")
      |> String.replace(~r/Mr. /, "")
      |> String.downcase()
      |> String.replace(~r/[^a-z]/, "_")
    end

    defp random_zip_code do
      Enum.take_random(
        [
          "56068",
          "56070",
          "56072",
          "56073",
          "56075",
          "56076",
          "56077",
          "56333",
          "56564",
          "56566",
          "56567"
        ],
        1
      )
      |> hd
    end

    defp random_mobile_phone_number do
      hd(Enum.take_random(["0171", "0151", "0172", "0160", "0170", "0157"], 1)) <>
        Phone.EnUs.subscriber_number(8)
    end

    defp opposite_gender("male") do
      "female"
    end

    defp opposite_gender("female") do
      "male"
    end

    defp download_photo(unsplash_id, filename) do
      url =
        "https://images.unsplash.com/#{unsplash_id}"

      %HTTPoison.Response{body: body} =
        HTTPoison.get!(url, [], timeout: 50_000, recv_timeout: 50_000)

      dest =
        Path.join(Application.app_dir(:animina, "priv/static/uploads"), Path.basename(filename))

      File.write!(dest, body)
      %{size: size} = File.stat!(dest)

      %{
        filename: filename,
        original_filename: filename,
        ext: "png",
        mime: "image/png",
        size: size
      }
    end

    defp get_headline_id(subject) do
      Headline
      |> Ash.Query.for_read(:by_subject, %{subject: subject})
      |> Ash.read_one()
      |> case do
        {:ok, headline} -> headline.id
        _ -> nil
      end
    end

    defp minimum_partner_age(age) do
      if age < 29 do
        18
      else
        age - 10
      end
    end

    def create_random_flag(user, color) do
      flag = Flag.read!() |> Enum.random()

      position =
        case UserFlags.read!()
             |> Enum.filter(fn %{user_id: id} -> id == user.id end) do
          [] -> 1
          list -> length(list) + 1
        end

      case UserFlags.create(%{
             user_id: user.id,
             flag_id: flag.id,
             position: position,
             color: color
           }) do
        {:ok, user_flag} -> {:ok, user_flag}
        _ -> {:error, nil}
      end
    end

    def get_random_photo(all_photos, category) do
      random_photo =
        Enum.filter(all_photos, fn photo -> photo.category == category end) |> Enum.random()

      unused_photos = Enum.reject(all_photos, fn photo -> photo.id == random_photo.id end)

      {random_photo, unused_photos}
    end

    def all_photos do
      [
        %{
          id: "photo-1502680390469-be75c86b636f",
          category: "hobby"
        },
        %{
          id: "photo-1563575044224-569da2f35b01",
          category: "hobby"
        },
        %{
          id: "photo-1515017671634-012cb9dc6ed0",
          category: "hobby"
        },
        %{
          id: "photo-1605264522799-1996bdbe5f72",
          category: "hobby"
        },
        %{
          id: "photo-1613085411234-9c83af5562d8",
          category: "hobby"
        },
        %{
          id: "photo-1632714394522-2916aac896e8",
          category: "hobby"
        },
        %{
          id: "photo-1556908153-1055164fe2df",
          category: "hobby"
        },
        %{
          id: "photo-1556909114-44e3e70034e2",
          category: "hobby"
        },
        %{
          id: "photo-1556911073-a517e752729c",
          category: "hobby"
        },
        %{
          id: "photo-1610552050890-fe99536c2615",
          category: "landscape"
        },
        %{
          id: "photo-1621847468516-1ed5d0df56fe",
          category: "landscape"
        },
        %{
          id: "photo-1620301598483-f872a86a58af",
          category: "landscape"
        },
        %{
          id: "photo-1628087234845-254f15abd82a",
          category: "landscape"
        },
        %{
          id: "photo-1616445404301-7433dc521d1f",
          category: "landscape"
        },
        %{
          id: "photo-1507525428034-b723cf961d3e",
          category: "landscape"
        },
        %{
          id: "photo-1509233725247-49e657c54213",
          category: "landscape"
        },
        %{
          id: "photo-1519046904884-53103b34b206",
          category: "landscape"
        }
      ]
    end

    def random_photo_id("hobby") do
      Enum.take_random(
        [
          "photo-1502680390469-be75c86b636f",
          "photo-1563575044224-569da2f35b01",
          "photo-1515017671634-012cb9dc6ed0",
          "photo-1605264522799-1996bdbe5f72",
          "photo-1613085411234-9c83af5562d8",
          "photo-1632714394522-2916aac896e8",
          "photo-1556908153-1055164fe2df",
          "photo-1556909114-44e3e70034e2",
          "photo-1556911073-a517e752729c"
        ],
        1
      )
      |> hd
    end

    def random_photo_id("landscape") do
      Enum.take_random(
        [
          "photo-1610552050890-fe99536c2615",
          "photo-1621847468516-1ed5d0df56fe",
          "photo-1620301598483-f872a86a58af",
          "photo-1628087234845-254f15abd82a",
          "photo-1616445404301-7433dc521d1f",
          "photo-1507525428034-b723cf961d3e",
          "photo-1509233725247-49e657c54213",
          "photo-1519046904884-53103b34b206"
        ],
        1
      )
      |> hd
    end

    defp pick_a_random_photo(available_photos) do
      random_photo_data =
        case :rand.uniform() do
          x when x <= 0.33 ->
            Enum.filter(available_photos, fn photo -> photo.category == "hobby" end)
            |> Enum.random()

          x when x <= 0.66 ->
            Enum.filter(available_photos, fn photo -> photo.category == "landscape" end)
            |> Enum.random()

          _ ->
            nil
        end

      random_photo =
        case random_photo_data do
          nil -> nil
          _ -> download_photo(random_photo_data.id, "#{Faker.UUID.v4()}.png")
        end

      unused_photos =
        case random_photo_data do
          nil -> available_photos
          _ -> Enum.reject(available_photos, fn photo -> photo.id == random_photo_data.id end)
        end

      {random_photo, unused_photos}
    end

    defp print_table(users) do
      IO.puts("|--------|----------------------------------------------|")
      IO.puts("| Gender | Profile URL                                  |")
      IO.puts("|--------|----------------------------------------------|")

      Enum.each(users, fn user ->
        username = "#{user.username}"

        IO.puts(
          "| #{user.gender |> String.pad_trailing(6)} | http://localhost:4000/#{String.pad_trailing(username, 22)} |"
        )
      end)

      IO.puts("|--------|----------------------------------------------|")

      IO.puts("")
      IO.puts("The default password for these dummy accounts is 'test'.\n")
    end
  end
end
