# gridlearner

![](other/screenshots/1.png?raw=true)
![](other/screenshots/2.png?raw=true)

single-file web application for displaying pairs from space-separated dsv file content in grid format.
the grids function as interactive, spatial memory-matching learning games, loosely akin to the game "concentration" or flashcards.
this application is useful for memorizing new information and reinforcing recall and association skills.

hosted with example data [here](https://sph.mn/other/chinese/gridlearner-cn.html).

four game modes are available:
* group
  * like a batch-version of a typically serial spaced-repetition software
  * users receive hints from the system but can ultimately choose what to learn when
  * it emphasizes simplicity. users are not asked to select an ease for each review, rather the user decides based on their needs if a card should be reset
  * long-tap to affirm cards. cards will be highlighted in a different color when due
  * uses the 3-column format for files (if unsure what to set for the child column, just duplicate the child and answer column)
  * its advanced feature is to group by hierarchical nesting. the associations from the data file are taken as a tree or optionally as a graph. this feature should be suitable for learning hierarchical data
* choice
  * match each question to the correct answer mixed with incorrect answers
  * incorrect answers increase the mistake highlight on the question
  * correct answers minimize the multiple choice entry
* pair
  * match questions with their corresponding answers
  * answer cards are sorted alphabetically to allow finding them when there are many cards without giving away the answer
* synonym
  * match questions which have the same answer
  * this requires that there actually are questions with the same answer, otherwise no cards will be displayed
* flip
  * just lists the questions individually
  * tap to reveal answers

# file formats
to create data files, one can use a spreadsheet application and save as csv with the delimiter set to the space character.

a 2-column format of question and answer is the main format used by most modes.
a 3-column format of parent, child, and answer is the format used by the group mode.

# hosting
it is possible to download the application and use it offline or host it somewhere else.
the entire application is contained within a single html file. you can copy the file from the compiled/ directory and open it directly in a browser to use the application.

# license
gpl3+

# possible enhancements
* data export function, to better persist configuration
* editing decks directly in the user interface