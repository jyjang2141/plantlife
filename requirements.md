# Plant Life

## Main Objective
We are making an iOS app for students in the 2nd-5th grade who are interested in plants, nature, and learning how to care for living things. After using our app, students should be able to identify common plants, describe important facts about them, explain what plants need to survive, and recognize environmental dangers that can affect plant health.

## Features:
* Plant Identification
* Virtual Garden
* Journal

### Plant Identification
The core interaction begins when a student encounters a real plant and takes a picture of it using the app. The student will be prompted through a series of questions to engage their observational skills before the app will identify the plant using an AI model and provide a short age-appropriate summary with facts about the plant, including what it needs to grow, where it commonly grows, and possible environmental dangers that can affect it.
\
The questions the student will be asked are:
1. What kind of plant is this? (flower, tree, shrub, etc.)
2. Describe the size of the plant
3. What does it look like? (color, shape, texture)
4. Where did you find this plant?
5. What terrain do you think this plant grows in? (desert, sunny, shady)
6. Additional notes?

All of the questions should be required except the last question. All questions are free text except the 5th question about terrains which should be a multiple choice reflecting the three terrains in the game. If the student answers incorrectly, they should be informed why their answer was wrong, and why the plant needs to be in a different terrain.

### Virtual Garden
Once the plant is identified, it is added to the virtual garden. The app will automatically place it in the correct terrain after giving the student feedback on their response to the initial observation question about terrains. The student will be able to care for the plant over time and record observations of the plant growth in their journal. The virtual garden will be separated into three different terrains: desert bed, sunny bed, and shady corner.

The plants will grow over time when cared for and require maintanence tasks like watering, pruning, and pest control. If they are not cared for, they should wilt and eventually die. The user will be able to move their plant within a specific terrain but it will not affect the amount of sunlight the plant receives. The timing of the care will be on a slighly expedited schedule compared to real time. For example, watering will be expected to be done every 6-48 hours, depending on the type of plant. Watering frequencies should reflect the needs of the real plant. Gradual wilting should occur immediately after the missed watering. The plant should die if not cared for in 3 days (72 hours). The other events like pruning and pest control will happen at random occurrences. They will pop up as a mini game to address the specific need of the plant.

When a plant dies, the plant will not be able to be revived. The student will journal about what went wrong with the care for that plant that led to its death before the plant is removed from the garden.

### Journal
The journal will be available per plant and provides a space for the student to write about their observations. Each entry should be timestamped so the student will be able to see progress over time.

## Visual Design
The app will be playful and engaging for a younger audience. Common plants will have a built-in icon that will display in the virtual garden. There will be icons for the following plants at these stages: sprout, seedling, vegetating, budding, flowering, and ripening. Each plant will only have the stages that make sense for that type of plant. All other plants will resort to a default plant icon with the basic stages including sprout, seedling and vegetating.
The following plants will have a built-in icon:
* Plants
    * Daisy
    * Sunflower
    * Cactus
    * Tulip
    * Rose
    * Poppy
    * Orchid
* Vegetables/Fruits
    * Corn
    * Tomato
    * Cucumber
    * Pumpkin
    * Strawberries
* Trees
    * Oak
    * Maple
    * Pine
    * Palm
* Other
    * Fern
    * Grass
    * Succulent
    * Shrub
    * Basil
    * Bush

## Data Storage
The app will not store any GPS information nor will it track location. Each user should have an account that stores the plants they have identified and are growing in their garden.