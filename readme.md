# gridlearner

![](other/screenshots/1.png?raw=true)
![](other/screenshots/2.png?raw=true)

single-file web application for displaying pairs from space-separated dsv file content in grid format.
the grids function as interactive, spatial memory-matching learning games, loosely akin to the game "concentration" or flashcards.
this application is useful for memorizing new information and reinforcing recall and association skills.

hosted with example data [here](https://sph.mn/other/chinese/gridlearner-cn.html).

four game modes are available:
* choice: match each question to the right answer mixed with incorrect answers
* pair: match questions with their corresponding answers
* synonym: match questions which have the same answer
* single: click to reveal one answer at a time

# installation
the entire application is contained within a single html file. you can copy the file from the compiled/ directory and open it directly in a browser to use the application, even offline, as it does not require internet access.

to make the application accessible over a network, serve the html file using a web server. you can modify or extend the application and host it elsewhere if needed.

# license
gpl3

# possible enhancements
* export function, to better persist configuration
* creating and editing decks directly in the user interface