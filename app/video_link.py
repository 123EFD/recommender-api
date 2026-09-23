# Curated YouTube links for video chunk topics
# Maps the topic names in our database to high-quality CS lecture videos

CURATED_VIDEOS = {
    "Reinforcement Learning High Res": "https://www.youtube.com/watch?v=2pWv7GOvuf0",
    "Ml For Health High Res": "https://www.youtube.com/watch?v=Gxs-HBIS0cU",
    "Deep Learning High Res": "https://www.youtube.com/watch?v=aircAruvnKk",
    "Numerics High Res": "https://www.youtube.com/watch?v=fNk_zzaMoSs",
    "Cryptocurrency High Res": "https://www.youtube.com/watch?v=bBC-nXj3Ng4",
    "Theory Of Computation High Res": "https://www.youtube.com/watch?v=58N2N7zJGrQ",
    "Cognitive Robotics High Res": "https://www.youtube.com/watch?v=SIIiMGOelnE",
    "Computer Vision 2 2 High Res": "https://www.youtube.com/watch?v=vT1JzLTH4G4",
    "Image Processing High Res": "https://www.youtube.com/watch?v=QMLbTEQJCaI",
}

def get_video_url(topic):
    return CURATED_VIDEOS.get(topic, "https://www.youtube.com/results?search_query=" + topic.replace(" ", "+"))
