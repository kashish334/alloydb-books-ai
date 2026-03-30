-- ============================================================
-- BookMind: AlloyDB AI Book Library Dataset
-- Use case: Querying a book catalog using natural language
-- ============================================================

-- Enable AlloyDB AI extension for Vertex AI ML integration
CREATE EXTENSION IF NOT EXISTS google_ml_integration CASCADE;
CREATE EXTENSION IF NOT EXISTS vector CASCADE;

-- ── Create books table ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS books (
    id                SERIAL PRIMARY KEY,
    title             VARCHAR(500)    NOT NULL,
    author            VARCHAR(300)    NOT NULL,
    genre             VARCHAR(100)    NOT NULL,
    publication_year  INTEGER,
    pages             INTEGER,
    rating            NUMERIC(3,2)    CHECK (rating BETWEEN 1.00 AND 5.00),
    language          VARCHAR(50)     DEFAULT 'English',
    description       TEXT,
    is_bestseller     BOOLEAN         DEFAULT FALSE,
    price_usd         NUMERIC(6,2),
    -- Vector embedding column for semantic search (AlloyDB AI feature)
    embedding         VECTOR(768)
);

-- Index for fast rating-based queries
CREATE INDEX IF NOT EXISTS idx_books_rating ON books(rating DESC);
CREATE INDEX IF NOT EXISTS idx_books_genre ON books(genre);
CREATE INDEX IF NOT EXISTS idx_books_year ON books(publication_year);
CREATE INDEX IF NOT EXISTS idx_books_bestseller ON books(is_bestseller);

-- ── Seed Data (100 diverse books) ────────────────────────────
INSERT INTO books (title, author, genre, publication_year, pages, rating, language, description, is_bestseller, price_usd) VALUES
-- Science Fiction
('Dune', 'Frank Herbert', 'Science Fiction', 1965, 688, 4.83, 'English', 'Epic saga of politics, religion, and ecology on a desert planet coveted for its spice.', TRUE, 14.99),
('The Martian', 'Andy Weir', 'Science Fiction', 2011, 369, 4.76, 'English', 'An astronaut must survive alone on Mars using science and ingenuity.', TRUE, 12.99),
('Ender''s Game', 'Orson Scott Card', 'Science Fiction', 1985, 352, 4.71, 'English', 'A gifted child is trained to lead humanity''s defense against alien invasion.', TRUE, 11.99),
('The Hitchhiker''s Guide to the Galaxy', 'Douglas Adams', 'Science Fiction', 1979, 193, 4.68, 'English', 'Comic sci-fi adventure following an Earthman whisked across the universe.', TRUE, 9.99),
('Neuromancer', 'William Gibson', 'Science Fiction', 1984, 271, 4.31, 'English', 'Founding cyberpunk novel about a washed-up hacker hired for a mysterious heist.', FALSE, 10.99),
('Foundation', 'Isaac Asimov', 'Science Fiction', 1951, 244, 4.62, 'English', 'A mathematician predicts the fall of civilization and works to shorten the dark age.', TRUE, 11.99),
('Snow Crash', 'Neal Stephenson', 'Science Fiction', 1992, 440, 4.44, 'English', 'In a near-future America, a hacker-pizza-deliverer fights a mind-destroying drug.', FALSE, 13.99),
('Project Hail Mary', 'Andy Weir', 'Science Fiction', 2021, 476, 4.89, 'English', 'A lone astronaut wakes with amnesia and must save Earth from extinction.', TRUE, 15.99),
('Children of Time', 'Adrian Tchaikovsky', 'Science Fiction', 2015, 600, 4.61, 'English', 'Uplifted spiders develop civilization while the last humans seek a new home.', FALSE, 14.99),
('Blindsight', 'Peter Watts', 'Science Fiction', 2006, 384, 4.22, 'English', 'A crew of posthumans investigates an alien signal near Pluto.', FALSE, 12.99),

-- Fantasy
('The Way of Kings', 'Brandon Sanderson', 'Fantasy', 2010, 1007, 4.82, 'English', 'Sweeping epic of war, magic, and redemption on a storm-swept world.', TRUE, 16.99),
('A Game of Thrones', 'George R.R. Martin', 'Fantasy', 1996, 694, 4.72, 'English', 'Noble families battle for control of the Iron Throne in a brutal medieval world.', TRUE, 14.99),
('The Name of the Wind', 'Patrick Rothfuss', 'Fantasy', 2007, 662, 4.74, 'English', 'The legend of Kvothe, the most feared magician alive, in his own words.', TRUE, 13.99),
('American Gods', 'Neil Gaiman', 'Fantasy', 2001, 465, 4.42, 'English', 'Old gods battle new ones for the soul of America.', TRUE, 13.99),
('Mistborn', 'Brandon Sanderson', 'Fantasy', 2006, 541, 4.77, 'English', 'In an ash-covered world, a crew plans to overthrow the immortal Lord Ruler.', TRUE, 13.99),
('The Lies of Locke Lamora', 'Scott Lynch', 'Fantasy', 2006, 499, 4.68, 'English', 'A master thief''s brilliant heist unravels in a Renaissance-style city.', FALSE, 12.99),
('Gardens of the Moon', 'Steven Erikson', 'Fantasy', 1999, 666, 4.31, 'English', 'First in the vast Malazan Book of the Fallen military fantasy series.', FALSE, 14.99),
('The Shadow of the Wind', 'Carlos Ruiz Zafón', 'Fantasy', 2001, 487, 4.64, 'Spanish', 'A boy finds a mysterious book whose author seems to have been erased from history.', TRUE, 13.99),

-- Mystery / Thriller
('Gone Girl', 'Gillian Flynn', 'Mystery', 2012, 422, 4.27, 'English', 'On their anniversary, Nick Dunne''s wife Amy disappears and clues point to him.', TRUE, 12.99),
('The Girl with the Dragon Tattoo', 'Stieg Larsson', 'Thriller', 2005, 672, 4.41, 'Swedish', 'A disgraced journalist and a hacker investigate a 40-year-old disappearance.', TRUE, 13.99),
('In the Woods', 'Tana French', 'Mystery', 2007, 429, 4.18, 'English', 'A detective investigates a murder near the woods where he survived a childhood trauma.', FALSE, 11.99),
('Big Little Lies', 'Liane Moriarty', 'Mystery', 2014, 460, 4.39, 'English', 'Three women''s lives become entangled in a murder mystery at a school fundraiser.', TRUE, 12.99),
('Rebecca', 'Daphne du Maurier', 'Mystery', 1938, 449, 4.56, 'English', 'A young bride is haunted by the memory of her husband''s first wife at Manderley.', TRUE, 9.99),
('The Thursday Murder Club', 'Richard Osman', 'Mystery', 2020, 382, 4.28, 'English', 'Four retirees in a peaceful village solve real murders as a hobby.', TRUE, 12.99),
('Knives Out', 'Rian Johnson', 'Mystery', 2019, 288, 4.11, 'English', 'A detective investigates the death of a beloved crime novelist after a family gathering.', FALSE, 10.99),

-- Horror
('It', 'Stephen King', 'Horror', 1986, 1138, 4.62, 'English', 'A shape-shifting monster terrorizes a small town for decades, targeting children.', TRUE, 16.99),
('The Haunting of Hill House', 'Shirley Jackson', 'Horror', 1959, 246, 4.43, 'English', 'Four people explore a notoriously haunted mansion and struggle to maintain their sanity.', TRUE, 10.99),
('Pet Sematary', 'Stephen King', 'Horror', 1983, 374, 4.44, 'English', 'A family discovers a burial ground that can bring the dead back — but wrong.', TRUE, 12.99),
('House of Leaves', 'Mark Z. Danielewski', 'Horror', 2000, 709, 4.31, 'English', 'A labyrinthine novel about a house that is larger on the inside than outside.', FALSE, 17.99),
('Mexican Gothic', 'Silvia Moreno-Garcia', 'Horror', 2020, 301, 4.13, 'English', 'A glamorous socialite investigates strange happenings at an eerie mansion in 1950s Mexico.', TRUE, 13.99),

-- Romance
('Pride and Prejudice', 'Jane Austen', 'Romance', 1813, 432, 4.78, 'English', 'Elizabeth Bennet navigates love, class, and family in Regency England.', TRUE, 7.99),
('Outlander', 'Diana Gabaldon', 'Romance', 1991, 850, 4.63, 'English', 'A WWII nurse is transported to 18th century Scotland and falls for a Highland warrior.', TRUE, 14.99),
('The Notebook', 'Nicholas Sparks', 'Romance', 1996, 214, 4.32, 'English', 'A love story of two young people who fall in love in the 1940s South.', TRUE, 11.99),
('Me Before You', 'Jojo Moyes', 'Romance', 2012, 369, 4.54, 'English', 'A girl takes a job caring for a wealthy quadriplegic and they fall in love.', TRUE, 12.99),
('The Hating Game', 'Sally Thorne', 'Romance', 2016, 384, 4.31, 'English', 'Two rival executive assistants discover their animosity might be attraction.', TRUE, 11.99),

-- Biography
('Steve Jobs', 'Walter Isaacson', 'Biography', 2011, 630, 4.41, 'English', 'Definitive biography of Apple''s visionary co-founder based on 40+ interviews.', TRUE, 16.99),
('Becoming', 'Michelle Obama', 'Biography', 2018, 448, 4.72, 'English', 'The former First Lady''s intimate memoir about her journey from Chicago to the White House.', TRUE, 14.99),
('The Diary of a Young Girl', 'Anne Frank', 'Biography', 1947, 283, 4.78, 'English', 'A Jewish teenager''s moving account of hiding from the Nazis in Amsterdam.', TRUE, 8.99),
('Long Walk to Freedom', 'Nelson Mandela', 'Biography', 1994, 656, 4.71, 'English', 'Mandela''s autobiography from his Xhosa village childhood to his presidency.', TRUE, 14.99),
('Born a Crime', 'Trevor Noah', 'Biography', 2016, 304, 4.82, 'English', 'The Daily Show host''s hilarious and heartbreaking memoir of growing up in apartheid South Africa.', TRUE, 13.99),
('Educated', 'Tara Westover', 'Biography', 2018, 334, 4.71, 'English', 'A woman raised by survivalist parents who never attended school earns a PhD from Cambridge.', TRUE, 14.99),

-- History
('Sapiens', 'Yuval Noah Harari', 'History', 2011, 443, 4.61, 'English', 'A sweeping account of the entire history of humankind across 70,000 years.', TRUE, 14.99),
('Guns, Germs, and Steel', 'Jared Diamond', 'History', 1997, 480, 4.32, 'English', 'Why did Western civilizations come to dominate the world? An ecological explanation.', TRUE, 14.99),
('The Silk Roads', 'Peter Frankopan', 'History', 2015, 656, 4.44, 'English', 'Revisionist world history that puts the trade routes of the Middle East at center.', FALSE, 15.99),
('A Short History of Nearly Everything', 'Bill Bryson', 'History', 2003, 544, 4.68, 'English', 'Bryson explores the history of science from the Big Bang to modern civilization.', TRUE, 14.99),
('The Warmth of Other Suns', 'Isabel Wilkerson', 'History', 2010, 622, 4.81, 'English', 'Epic account of the Great Migration of Black Americans from the South.', TRUE, 16.99),

-- Self-Help
('Atomic Habits', 'James Clear', 'Self-Help', 2018, 319, 4.81, 'English', 'Practical framework for building good habits and breaking bad ones using tiny changes.', TRUE, 13.99),
('The Power of Now', 'Eckhart Tolle', 'Self-Help', 1997, 229, 4.29, 'English', 'A guide to spiritual enlightenment through living fully in the present moment.', TRUE, 11.99),
('Thinking, Fast and Slow', 'Daniel Kahneman', 'Self-Help', 2011, 499, 4.52, 'English', 'Nobel laureate explains the two systems that drive the way we think and make decisions.', TRUE, 14.99),
('Man''s Search for Meaning', 'Viktor E. Frankl', 'Self-Help', 1946, 165, 4.74, 'English', 'Holocaust survivor''s account of finding purpose even in the worst conditions.', TRUE, 9.99),
('The 7 Habits of Highly Effective People', 'Stephen Covey', 'Self-Help', 1989, 381, 4.31, 'English', 'Principle-centered approach for solving personal and professional problems.', TRUE, 13.99),
('Deep Work', 'Cal Newport', 'Self-Help', 2016, 304, 4.48, 'English', 'The ability to focus without distraction is the superpower of the 21st century.', TRUE, 12.99),
('The Subtle Art of Not Giving a F*ck', 'Mark Manson', 'Self-Help', 2016, 224, 4.26, 'English', 'A counterintuitive approach to living a good life by choosing your struggles wisely.', TRUE, 11.99),

-- Literary Fiction
('To Kill a Mockingbird', 'Harper Lee', 'Fiction', 1960, 281, 4.81, 'English', 'A young girl witnesses her father defend a Black man falsely accused in 1930s Alabama.', TRUE, 10.99),
('1984', 'George Orwell', 'Fiction', 1949, 328, 4.73, 'English', 'A dystopian novel about totalitarian surveillance and the destruction of truth.', TRUE, 9.99),
('The Great Gatsby', 'F. Scott Fitzgerald', 'Fiction', 1925, 180, 4.21, 'English', 'The enigmatic Jay Gatsby pursues the American Dream in Jazz Age New York.', TRUE, 8.99),
('One Hundred Years of Solitude', 'Gabriel García Márquez', 'Fiction', 1967, 417, 4.64, 'Spanish', 'Multi-generational saga of the Buendía family in the mythical town of Macondo.', TRUE, 13.99),
('The Catcher in the Rye', 'J.D. Salinger', 'Fiction', 1951, 224, 4.12, 'English', 'Teenage Holden Caulfield''s alienated wandering through New York City.', TRUE, 9.99),
('Beloved', 'Toni Morrison', 'Fiction', 1987, 321, 4.42, 'English', 'A former slave is haunted by the ghost of her dead baby in post-Civil War Ohio.', TRUE, 11.99),
('The Kite Runner', 'Khaled Hosseini', 'Fiction', 2003, 371, 4.69, 'English', 'A man must atone for his childhood betrayal of his best friend in Afghanistan.', TRUE, 12.99),
('Normal People', 'Sally Rooney', 'Fiction', 2018, 273, 4.22, 'English', 'Two Irish teenagers navigate their complicated on-off relationship through college.', TRUE, 12.99),
('The Road', 'Cormac McCarthy', 'Fiction', 2006, 287, 4.47, 'English', 'A father and son walk through post-apocalyptic America, struggling to survive.', TRUE, 12.99),
('Never Let Me Go', 'Kazuo Ishiguro', 'Fiction', 2005, 288, 4.31, 'English', 'Students at a mysterious English boarding school discover their terrible purpose.', FALSE, 12.99),

-- Young Adult
('Harry Potter and the Sorcerer''s Stone', 'J.K. Rowling', 'Young Adult', 1997, 309, 4.91, 'English', 'An orphan discovers he is a wizard and begins his education at Hogwarts School.', TRUE, 10.99),
('The Hunger Games', 'Suzanne Collins', 'Young Adult', 2008, 374, 4.71, 'English', 'In a dystopian future, teens fight to the death in a televised spectacle.', TRUE, 11.99),
('Percy Jackson and the Lightning Thief', 'Rick Riordan', 'Young Adult', 2005, 377, 4.66, 'English', 'A troubled kid discovers he is the son of Poseidon and must prevent a war between gods.', TRUE, 10.99),
('The Fault in Our Stars', 'John Green', 'Young Adult', 2012, 313, 4.52, 'English', 'Two teens with cancer fall in love and grapple with life, death, and literature.', TRUE, 11.99),
('Divergent', 'Veronica Roth', 'Young Adult', 2011, 487, 4.31, 'English', 'In a future Chicago, society is divided into factions based on virtues.', TRUE, 10.99),

-- Non-Fiction
('The Body', 'Bill Bryson', 'Non-Fiction', 2019, 447, 4.68, 'English', 'A tour of the human body, explaining how it works and what can go wrong.', TRUE, 14.99),
('Quiet: The Power of Introverts', 'Susan Cain', 'Non-Fiction', 2012, 333, 4.61, 'English', 'How introverts are undervalued in our culture and their hidden strengths.', TRUE, 12.99),
('The Immortal Life of Henrietta Lacks', 'Rebecca Skloot', 'Non-Fiction', 2010, 381, 4.57, 'English', 'The story of a woman whose cancer cells became immortal and changed medicine forever.', TRUE, 13.99),
('Educated', 'David Grann', 'Non-Fiction', 2017, 339, 4.62, 'English', 'A riveting true-crime investigation of murders in the Osage Nation in the 1920s.', TRUE, 13.99),
('Freakonomics', 'Steven D. Levitt', 'Non-Fiction', 2005, 268, 4.31, 'English', 'An economist and journalist explore the hidden side of everything with data.', TRUE, 11.99),

-- Children / Middle Grade
('Charlotte''s Web', 'E.B. White', 'Children', 1952, 184, 4.71, 'English', 'A pig named Wilbur befriends a spider named Charlotte who saves his life.', TRUE, 7.99),
('The Giver', 'Lois Lowry', 'Young Adult', 1993, 179, 4.52, 'English', 'In a seemingly perfect community, a boy discovers the dark truth behind the society.', TRUE, 9.99),
('Matilda', 'Roald Dahl', 'Children', 1988, 232, 4.77, 'English', 'A brilliant little girl with telekinetic powers triumphs over her dreadful family and school.', TRUE, 8.99),

-- Spanish language books
('Cien Años de Soledad', 'Gabriel García Márquez', 'Fiction', 1967, 417, 4.74, 'Spanish', 'La historia de la familia Buendía a lo largo de siete generaciones en Macondo.', TRUE, 12.99),
('El Alquimista', 'Paulo Coelho', 'Fiction', 1988, 177, 4.23, 'Spanish', 'Un pastor andaluz sigue su sueño de encontrar un tesoro en las pirámides de Egipto.', TRUE, 10.99),
('La Sombra del Viento', 'Carlos Ruiz Zafón', 'Mystery', 2001, 487, 4.64, 'Spanish', 'Un niño encuentra un libro misterioso en el Cementerio de los Libros Olvidados.', TRUE, 13.99),

-- French language books
('Le Petit Prince', 'Antoine de Saint-Exupéry', 'Fiction', 1943, 96, 4.67, 'French', 'Un aviateur rencontre un jeune prince venu d''une autre planète dans le désert.', TRUE, 8.99),

-- Recent releases
('Fourth Wing', 'Rebecca Yarros', 'Fantasy', 2023, 517, 4.54, 'English', 'A young woman enters a war college for dragon riders and falls for a rival.', TRUE, 15.99),
('Iron Flame', 'Rebecca Yarros', 'Fantasy', 2023, 623, 4.41, 'English', 'Sequel to Fourth Wing — Violet returns to Basgiath with new dangers awaiting.', TRUE, 16.99),
('Happy Place', 'Emily Henry', 'Romance', 2023, 389, 4.38, 'English', 'Exes must pretend to be together at their annual vacation with friends.', TRUE, 14.99),
('Tomorrow, and Tomorrow, and Tomorrow', 'Gabrielle Zevin', 'Fiction', 2022, 480, 4.47, 'English', 'Two video game designers build an empire spanning 30 years of friendship and creativity.', TRUE, 14.99),
('Lessons in Chemistry', 'Bonnie Garmus', 'Fiction', 2022, 390, 4.59, 'English', 'A female chemist in the 1960s becomes an unlikely cooking show host.', TRUE, 14.99),
('The Covenant of Water', 'Abraham Verghese', 'Fiction', 2023, 736, 4.61, 'English', 'Three generations of a South Indian family and a mysterious condition spanning a century.', FALSE, 16.99),
('Same as Ever', 'Morgan Housel', 'Non-Fiction', 2023, 240, 4.51, 'English', 'Stories about the things that never change in a world obsessed with what does.', TRUE, 13.99),
('Poor Things', 'Alasdair Gray', 'Fiction', 1992, 318, 4.23, 'English', 'A Victorian woman is brought back to life with a new brain and explores the world.', FALSE, 12.99);

-- ── Verify ───────────────────────────────────────────────────
SELECT COUNT(*) AS total_books FROM books;
SELECT genre, COUNT(*) as count, ROUND(AVG(rating),2) as avg_rating
FROM books
GROUP BY genre
ORDER BY count DESC;
