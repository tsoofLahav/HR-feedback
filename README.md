# Heart feedback app
<img width="453" alt="צילום מסך 2024-08-21 ב-14 06 40" src="https://github.com/user-attachments/assets/82e8b5e1-8319-48e4-8fec-f4c05e0aedb5">
## Project Overview
This project was developed as part of my practical experience in the Amir Amedi Brain Lab during the second year of my Computer Science and Cognition degree.
The app was created to support various studies conducted within the lab.
## Functionality
The app reads the user's heartbeat by using the phone's camera to capture data from the fingertip.
It then converts this data into vibrational sensations, which are transmitted to a Woojer suit via audio files, creating a biofeedback effect.
## Demo
The following video is a demo of the app functionality
https://youtube.com/shorts/tSjhg5ei5U4?feature=share
## How does it work?
The app takes short videos in a loop and send it to the server.
The backend of the app process the videos using PPG algorithem, that determine when a pulse accure based on the changes of color of the finger.
Then the app creat audio sound, that will be convert to vibrations in a woojer suit to create the bio feedback affect.
The app also calculate the avarage BPM,and print it to the screen.
### code
The frontend is written in Dart, uses a flutter package, and The backend was written using python.
