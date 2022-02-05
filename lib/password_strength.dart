import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kdbx/kdbx.dart';
import 'package:zxcvbn/zxcvbn.dart';

import 'argon2_params.dart';

const badWords = ['kee', 'keepass', 'kee.pm', 'master', 'keevault', 'vault'];
final zxcvbn = Zxcvbn();

Argon2StrengthCategory fuzzyStrength(String password, List<String> emailAddrParts) {
  final userInputs = [...badWords, ...emailAddrParts];
  final strength =
      zxcvbn.evaluate(password.substring(0, min(password.length, 80)), userInputs: userInputs).guesses_log10.round();
  final randomFactor = Random().nextDouble();
  Argon2StrengthCategory fuzzyStrength = Argon2StrengthCategory.veryLow;
  if (strength >= 21) {
    if (randomFactor > 0.4) {
      fuzzyStrength = Argon2StrengthCategory.veryHigh;
    } else {
      fuzzyStrength = Argon2StrengthCategory.high;
    }
  } else if (strength >= 18) {
    if (randomFactor > 0.8) {
      fuzzyStrength = Argon2StrengthCategory.veryHigh;
    } else if (randomFactor > 0.2) {
      fuzzyStrength = Argon2StrengthCategory.high;
    } else {
      fuzzyStrength = Argon2StrengthCategory.medium;
    }
  } else if (strength >= 15) {
    if (randomFactor > 0.8) {
      fuzzyStrength = Argon2StrengthCategory.high;
    } else if (randomFactor > 0.2) {
      fuzzyStrength = Argon2StrengthCategory.medium;
    } else {
      fuzzyStrength = Argon2StrengthCategory.low;
    }
  } else if (strength >= 12) {
    if (randomFactor > 0.8) {
      fuzzyStrength = Argon2StrengthCategory.medium;
    } else if (randomFactor > 0.2) {
      fuzzyStrength = Argon2StrengthCategory.low;
    } else {
      fuzzyStrength = Argon2StrengthCategory.veryLow;
    }
  } else {
    if (randomFactor > 0.6) {
      fuzzyStrength = Argon2StrengthCategory.low;
    } else {
      fuzzyStrength = Argon2StrengthCategory.veryLow;
    }
  }
  return fuzzyStrength;
}

double exactStrength(String password, List<String> emailAddrParts) {
  final userInputs = [...badWords, ...emailAddrParts];
  final strength =
      zxcvbn.evaluate(password.substring(0, min(password.length, 80)), userInputs: userInputs).guesses_log10.round();
  if (strength >= 21) {
    return 5;
  } else if (strength >= 19) {
    return 4.5;
  } else if (strength >= 18) {
    return 4;
  } else if (strength >= 16) {
    return 3.5;
  } else if (strength >= 14) {
    return 3;
  } else if (strength >= 13) {
    return 2.5;
  } else if (strength >= 12) {
    return 2;
  } else if (strength >= 11) {
    return 1.5;
  } else if (strength >= 9) {
    return 1;
  } else {
    return 0.5;
  }
}

Widget renderPasswordStrength(strength, rootJQueryEl, selectorOverride) {
  return RatingBarIndicator(
    rating: strength,
    itemBuilder: (context, index) => Icon(
      Icons.star,
      color: Colors.amber,
    ),
    itemCount: 5,
    itemSize: 50.0,
  );
}

class StrengthAssessedCredentials {
  Credentials credentials;
  final Argon2StrengthCategory strength;

  StrengthAssessedCredentials(ProtectedValue password, List<String> emailAddrParts)
      : strength = fuzzyStrength(password.getText(), emailAddrParts),
        credentials = Credentials(password);
}
