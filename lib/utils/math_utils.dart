import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

/// Mathematical utility functions for vector operations and similarity calculations
class MathUtils {
  /// Calculates the cosine similarity between two vectors
  /// Returns a value between -1 and 1, where 1 means identical vectors
  static double cosineSimilarity(List<double> vecA, List<double> vecB) {
    if (vecA.isEmpty || vecB.isEmpty) {
      return 0.0; // Handle empty vectors
    }
    
    if (vecA.length != vecB.length) {
      throw ArgumentError('Vectors must have the same dimension for cosine similarity calculation.');
    }

    double dotProduct = 0.0;
    double magnitudeA = 0.0;
    double magnitudeB = 0.0;

    for (int i = 0; i < vecA.length; i++) {
      dotProduct += vecA[i] * vecB[i];
      magnitudeA += vecA[i] * vecA[i];
      magnitudeB += vecB[i] * vecB[i];
    }

    magnitudeA = math.sqrt(magnitudeA);
    magnitudeB = math.sqrt(magnitudeB);

    if (magnitudeA == 0.0 || magnitudeB == 0.0) {
      return 0.0; // Handle zero vectors
    }

    return dotProduct / (magnitudeA * magnitudeB);
  }

  /// Calculates Euclidean distance between two vectors
  static double euclideanDistance(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length) {
      throw ArgumentError('Vectors must have the same dimension for distance calculation.');
    }

    double sum = 0.0;
    for (int i = 0; i < vecA.length; i++) {
      final diff = vecA[i] - vecB[i];
      sum += diff * diff;
    }

    return math.sqrt(sum);
  }

  /// Calculates Manhattan distance between two vectors
  static double manhattanDistance(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length) {
      throw ArgumentError('Vectors must have the same dimension for distance calculation.');
    }

    double sum = 0.0;
    for (int i = 0; i < vecA.length; i++) {
      sum += (vecA[i] - vecB[i]).abs();
    }

    return sum;
  }

  /// Normalizes a vector to unit length
  static List<double> normalizeVector(List<double> vector) {
    if (vector.isEmpty) return [];

    double magnitude = 0.0;
    for (final value in vector) {
      magnitude += value * value;
    }
    magnitude = math.sqrt(magnitude);

    if (magnitude == 0.0) return vector;

    return vector.map((value) => value / magnitude).toList();
  }

  /// Calculates the dot product of two vectors
  static double dotProduct(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length) {
      throw ArgumentError('Vectors must have the same dimension for dot product calculation.');
    }

    double result = 0.0;
    for (int i = 0; i < vecA.length; i++) {
      result += vecA[i] * vecB[i];
    }

    return result;
  }

  /// Calculates the magnitude (length) of a vector
  static double vectorMagnitude(List<double> vector) {
    double sum = 0.0;
    for (final value in vector) {
      sum += value * value;
    }
    return math.sqrt(sum);
  }

  /// Adds two vectors element-wise
  static List<double> addVectors(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length) {
      throw ArgumentError('Vectors must have the same dimension for addition.');
    }

    return List.generate(vecA.length, (i) => vecA[i] + vecB[i]);
  }

  /// Subtracts vector B from vector A element-wise
  static List<double> subtractVectors(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length) {
      throw ArgumentError('Vectors must have the same dimension for subtraction.');
    }

    return List.generate(vecA.length, (i) => vecA[i] - vecB[i]);
  }

  /// Multiplies a vector by a scalar
  static List<double> scalarMultiply(List<double> vector, double scalar) {
    return vector.map((value) => value * scalar).toList();
  }

  /// Calculates the mean of a list of numbers
  static double mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculates the standard deviation of a list of numbers
  static double standardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final meanValue = mean(values);
    final variance = values
        .map((value) => math.pow(value - meanValue, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return math.sqrt(variance);
  }

  /// Finds the k most similar vectors to a query vector using cosine similarity
  static List<MapEntry<int, double>> findMostSimilar(
    List<double> queryVector,
    List<List<double>> vectors, {
    int k = 5,
  }) {
    final similarities = <MapEntry<int, double>>[];
    
    for (int i = 0; i < vectors.length; i++) {
      final similarity = cosineSimilarity(queryVector, vectors[i]);
      similarities.add(MapEntry(i, similarity));
    }
    
    // Sort by similarity (descending) and take top k
    similarities.sort((a, b) => b.value.compareTo(a.value));
    return similarities.take(k).toList();
  }

  /// Calculates Jaccard similarity between two sets
  static double jaccardSimilarity(Set<dynamic> setA, Set<dynamic> setB) {
    if (setA.isEmpty && setB.isEmpty) return 1.0;
    
    final intersection = setA.intersection(setB);
    final union = setA.union(setB);
    
    return intersection.length / union.length;
  }

  /// Calculates Levenshtein distance between two strings
  static int levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    // Fill the matrix
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(
            matrix[i - 1][j] + 1, // deletion
            matrix[i][j - 1] + 1, // insertion
          ),
          matrix[i - 1][j - 1] + cost, // substitution
        );
      }
    }

    return matrix[a.length][b.length];
  }

  /// Calculates string similarity based on Levenshtein distance
  static double stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    
    final maxLength = math.max(a.length, b.length);
    if (maxLength == 0) return 1.0;
    
    final distance = levenshteinDistance(a, b);
    return 1.0 - (distance / maxLength);
  }

  /// Clamps a value between min and max
  static double clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  /// Linear interpolation between two values
  static double lerp(double a, double b, double t) {
    return a + (b - a) * clamp(t, 0.0, 1.0);
  }

  /// Maps a value from one range to another
  static double mapRange(
    double value,
    double fromMin,
    double fromMax,
    double toMin,
    double toMax,
  ) {
    final normalized = (value - fromMin) / (fromMax - fromMin);
    return lerp(toMin, toMax, normalized);
  }

  /// Generates a random vector of specified dimension
  static List<double> randomVector(int dimension, {double min = -1.0, double max = 1.0}) {
    final random = math.Random();
    return List.generate(
      dimension,
      (_) => min + random.nextDouble() * (max - min),
    );
  }

  /// Calculates the centroid of a list of vectors
  static List<double> centroid(List<List<double>> vectors) {
    if (vectors.isEmpty) return [];
    
    final dimension = vectors.first.length;
    final result = List.filled(dimension, 0.0);
    
    for (final vector in vectors) {
      for (int i = 0; i < dimension; i++) {
        result[i] += vector[i];
      }
    }
    
    for (int i = 0; i < dimension; i++) {
      result[i] /= vectors.length;
    }
    
    return result;
  }
}
