# Localink

Localink is a Flutter-based mobile application designed to enhance local connectivity and provide a platform where users can easily connect with people and resources in their nearby community. This project focuses on promoting engagement and local networking through a seamless and user-friendly mobile experience.

## Table of Contents

- [About the Project](#about-the-project)
- [Built With](#built-with)
- [Getting Started](#getting-started)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## About the Project

Localink is a mobile solution designed to bridge the gap between individuals and local services, events, and communities. The application allows users to discover and engage with people, places, and events within their locality. With Localink, users can access a range of localized features such as real-time event feeds, nearby service recommendations, and personalized local networking options.

### Key Objectives
- Facilitate connections among community members.
- Provide a comprehensive directory of local resources and services.
- Offer a platform for promoting local events and activities.

### Built With

- [Flutter](https://flutter.dev/) - A framework for building cross-platform mobile applications from a single codebase.
- [Firebase](https://firebase.google.com/) - Backend services for authentication, real-time database, and cloud storage.
- [Node.js](https://nodejs.org/) - Used for cloud functions to manage backend processes.
- [Cloudinary](https://cloudinary.com/) - Used for video upload, compression, and optimization.
- [Google Cloud Platform (GCP)](https://cloud.google.com/):
  - **Cloud Vision API** - For analyzing images to identify and tag objects or scenes.
  - **Cloud Natural Language API** - For analyzing and processing user-generated content.
- **Usage of the cloud functions**:
  1. **Offensive Language Check**: The function first checks if the user content contains inappropriate language using a custom-defined `containsOffensiveLanguage` function.
  2. **Sentiment Analysis**: Next, the Google Cloud Natural Language API analyzes the sentiment of the content to detect any negative sentiment. If the sentiment score is low (indicating negativity), the content is flagged as inappropriate.
  3. **Image Safety Check**: For each image URL, the Google Cloud Vision API’s Safe Search Detection feature assesses the images to ensure they don't contain adult, violent, or disturbing content.


## Getting Started

To get started with Localink, you’ll need a basic Flutter setup. Make sure Flutter is installed on your development machine, and all required plugins and dependencies are up-to-date.

### Features

- **Community Discovery**: Find people, places, and events happening nearby.
- **Event Feed**: A dynamic feed of upcoming and ongoing local events.
- **Service Directory**: A categorized list of nearby services like restaurants, gyms, and other essential businesses.
- **User Profiles**: Personalized user profiles to enhance local networking.
- **Notifications**: Timely alerts and updates for local events and nearby happenings.

## Installation

1. Clone the Localink repository to your local machine.
2. Open the project in your preferred Flutter-supported IDE.
3. Ensure all dependencies are resolved in your `pubspec.yaml` file.

## Usage

Once set up, Localink provides an intuitive interface for users to explore their local community. Navigate through the app to access event listings, connect with nearby users, and find local resources and services. 

## Contributing

Contributions are welcome! If you’d like to suggest improvements or add new features, please follow these steps:
1. Fork the repository.
2. Create a new branch for your feature.
3. Submit a pull request detailing your changes.

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact
For inquiries or feedback:
- **Email**: [mnsoqar1@gmail.com]
- **Project Link**: [https://github.com/Mohammad-soqar/localink_sm]
