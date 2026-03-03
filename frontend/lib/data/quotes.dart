import 'dart:math';

const List<String> messages = [
  "\"Don't be surprised when a crack in the ice appears under your feet.\" - Pink Floyd",
  "\"'OOF'[someone being hit]\" - Pink Floyd",
  "\"Hey! Teachers! Leave them kids alone!\" - Pink Floyd",
  "\"If you don't eat yer meat, you can't have any pudding. How can you have any pudding if you don't eat yer meat?\" - Pink Floyd",
  "\"'Yes, a collect call for Mrs. Floyd from Mr. Floyd.\n Will you accept the charges from United States?'\" - Pink Floyd",
  "\"I can feel one of my turns coming on.\" - Pink Floyd",
  "\"Would you like to call the cops?\n Do you think it's time I stopped?\" - Pink Floyd",
  "\"Why are you running away?\" - Pink Floyd",
  "\"And I dont need no drugs to calm me.\" - Pink Floyd",
  "\"All in all it was all just bricks in the wall.\" - Pink Floyd",
  "\"No matter how he tried, He could not break free.\n And the worms ate into his brain.\" - Pink Floyd",
  "\"Got those swollen hand blues.\" - Pink Floyd",
  "\"All you need to do is follow the worms.\" - Pink Floyd",
  "\"The prisoner who now stands before you was caught red-handed showing feelings\n Showing feelings of an almost human nature; \nThis will not do.\" - Pink Floyd",
  "\"They must have taken my marbles away.\" - Pink Floyd",
  "\"There is no pain you are receding\" - Pink Floyd",
  "\"Are there any queers in the theater tonight?\" - Pink Floyd",
  "\"If I had my way, I'd have all of you shot!\" - Pink Floyd",
  "\"'Go on Judge! Shit on him!'\" - Pink Floyd",
  "\"Tear down the wall!\" - Pink Floyd",
  "\"Some stagger and fall, after all it's not easy\n Banging your heart against some mad bugger's wall.\" - Pink Floyd",
  "\"This Roman Meal bakery thought you'd like to know.\" - Pink Floyd",
];

final Random _random = Random();

String getRandomMessage() {
  return messages[_random.nextInt(messages.length)];
}

String getHourlyMessage() {
  final now = DateTime.now().toUtc();
  final int hourBucket = now.millisecondsSinceEpoch ~/ (1000 * 60 * 60);
  int x = hourBucket;
  x = (x * 1664525 + 1013904223) & 0x7fffffff;
  final int index = x % messages.length; //get only up to message length
  return messages[index];
}
