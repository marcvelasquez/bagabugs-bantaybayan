import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for running TensorFlow Lite model inference
/// Handles loading models and running predictions offline
class TFLiteInferenceService {
  // Model interpreters
  Interpreter? _probabilityInterpreter;
  Interpreter? _depthInterpreter;

  // Feature scaler parameters (loaded from JSON)
  List<double>? _scalerMean;
  List<double>? _scalerScale;
  List<String>? _featureColumns;

  // Model paths
  static const String _probabilityModelPath = 'assets/ml_models/flood_probability_model.tflite';
  static const String _depthModelPath = 'assets/ml_models/flood_depth_model.tflite';
  static const String _scalerParamsPath = 'assets/ml_models/scaler_params.json';

  // Feature count
  static const int _numFeatures = 6;

  bool _isInitialized = false;

  /// Initialize the TFLite models and load scaler parameters
  Future<void> initialize() async {
    if (_isInitialized) {
      print('TFLiteInferenceService already initialized');
      return;
    }

    try {
      print('Initializing TFLite models...');

      // Load scaler parameters first
      await _loadScalerParams();

      // Load probability model
      _probabilityInterpreter = await _loadModel(_probabilityModelPath);
      print('✓ Loaded flood probability model');

      // Load depth model
      _depthInterpreter = await _loadModel(_depthModelPath);
      print('✓ Loaded flood depth model');

      _isInitialized = true;
      print('TFLite inference service initialized successfully');
    } catch (e) {
      print('❌ Error initializing TFLite models: $e');
      rethrow;
    }
  }

  /// Load a TFLite model from assets
  Future<Interpreter> _loadModel(String modelPath) async {
    try {
      // Load model options
      final options = InterpreterOptions();
      
      // Use 4 threads for faster inference
      options.threads = 4;

      // Load the model
      final interpreter = await Interpreter.fromAsset(
        modelPath,
        options: options,
      );

      // Allocate tensors
      interpreter.allocateTensors();

      // Verify model inputs/outputs
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;

      print('Model loaded: $modelPath');
      print('  Input shape: $inputShape');
      print('  Output shape: $outputShape');

      return interpreter;
    } catch (e) {
      print('Error loading model $modelPath: $e');
      rethrow;
    }
  }

  /// Load scaler parameters from JSON file
  Future<void> _loadScalerParams() async {
    try {
      final jsonString = await rootBundle.loadString(_scalerParamsPath);
      final params = json.decode(jsonString);

      _scalerMean = List<double>.from(params['mean']);
      _scalerScale = List<double>.from(params['scale']);
      _featureColumns = List<String>.from(params['feature_columns']);

      print('✓ Loaded scaler parameters');
      print('  Features: $_featureColumns');
    } catch (e) {
      print('Error loading scaler parameters: $e');
      rethrow;
    }
  }

  /// Apply StandardScaler transformation to features
  /// Formula: (x - mean) / scale
  List<double> _scaleFeatures(List<double> features) {
    if (_scalerMean == null || _scalerScale == null) {
      throw Exception('Scaler parameters not loaded');
    }

    if (features.length != _numFeatures) {
      throw ArgumentError(
        'Expected $_numFeatures features, got ${features.length}',
      );
    }

    final scaled = <double>[];
    for (int i = 0; i < features.length; i++) {
      final scaledValue = (features[i] - _scalerMean![i]) / _scalerScale![i];
      scaled.add(scaledValue);
    }

    return scaled;
  }

  /// Predict flood probability for given features
  /// 
  /// Features must be in order:
  /// [elevation, slope, flow_accumulation, dist_to_road, population, dist_to_landslide]
  /// 
  /// Returns probability value between 0.0 and 1.0
  Future<double> predictFloodProbability(List<double> features) async {
    if (!_isInitialized) {
      throw Exception('TFLite service not initialized. Call initialize() first.');
    }

    if (_probabilityInterpreter == null) {
      throw Exception('Probability model not loaded');
    }

    try {
      // Scale features
      final scaledFeatures = _scaleFeatures(features);

      // Prepare input tensor (batch size = 1)
      final input = [Float32List.fromList(scaledFeatures)];

      // Prepare output tensor
      final output = [Float32List(1)];

      // Run inference
      _probabilityInterpreter!.run(input, output);

      // Get prediction (clamp to 0-1 range)
      final prediction = output[0][0].clamp(0.0, 1.0);

      return prediction;
    } catch (e) {
      print('Error in flood probability prediction: $e');
      rethrow;
    }
  }

  /// Predict flood depth for given features
  /// 
  /// Features must be in order:
  /// [elevation, slope, flow_accumulation, dist_to_road, population, dist_to_landslide]
  /// 
  /// Returns depth in meters (typically 0.0 - 3.0+)
  Future<double> predictFloodDepth(List<double> features) async {
    if (!_isInitialized) {
      throw Exception('TFLite service not initialized. Call initialize() first.');
    }

    if (_depthInterpreter == null) {
      throw Exception('Depth model not loaded');
    }

    try {
      // Scale features
      final scaledFeatures = _scaleFeatures(features);

      // Prepare input tensor (batch size = 1)
      final input = [Float32List.fromList(scaledFeatures)];

      // Prepare output tensor
      final output = [Float32List(1)];

      // Run inference
      _depthInterpreter!.run(input, output);

      // Get prediction (clamp to non-negative)
      final prediction = output[0][0].clamp(0.0, double.infinity);

      return prediction;
    } catch (e) {
      print('Error in flood depth prediction: $e');
      rethrow;
    }
  }

  /// Run both predictions at once (more efficient)
  /// Returns {probability, depth}
  Future<Map<String, double>> predictBoth(List<double> features) async {
    final probability = await predictFloodProbability(features);
    final depth = await predictFloodDepth(features);

    return {
      'probability': probability,
      'depth': depth,
    };
  }

  /// Batch prediction for multiple locations (more efficient)
  /// Each element in featuresList should be a 6-element list
  Future<List<Map<String, double>>> predictBatch(
    List<List<double>> featuresList,
  ) async {
    final results = <Map<String, double>>[];

    for (final features in featuresList) {
      final prediction = await predictBoth(features);
      results.add(prediction);
    }

    return results;
  }

  /// Get feature column names in order
  List<String> get featureColumns => _featureColumns ?? [];

  /// Check if service is ready
  bool get isInitialized => _isInitialized;

  /// Get model info for debugging
  Map<String, dynamic> getModelInfo() {
    if (!_isInitialized) {
      return {'initialized': false};
    }

    return {
      'initialized': true,
      'num_features': _numFeatures,
      'feature_columns': _featureColumns,
      'scaler_mean': _scalerMean,
      'scaler_scale': _scalerScale,
      'probability_model': {
        'input_shape': _probabilityInterpreter?.getInputTensor(0).shape,
        'output_shape': _probabilityInterpreter?.getOutputTensor(0).shape,
      },
      'depth_model': {
        'input_shape': _depthInterpreter?.getInputTensor(0).shape,
        'output_shape': _depthInterpreter?.getOutputTensor(0).shape,
      },
    };
  }

  /// Release resources
  void dispose() {
    _probabilityInterpreter?.close();
    _depthInterpreter?.close();
    _probabilityInterpreter = null;
    _depthInterpreter = null;
    _isInitialized = false;
    print('TFLite models disposed');
  }

  /// Validate input features (for debugging)
  bool validateFeatures(List<double> features) {
    if (features.length != _numFeatures) {
      print('Invalid feature count: expected $_numFeatures, got ${features.length}');
      return false;
    }

    // Check for NaN or infinite values
    for (int i = 0; i < features.length; i++) {
      if (features[i].isNaN || features[i].isInfinite) {
        print('Invalid feature value at index $i: ${features[i]}');
        return false;
      }
    }

    return true;
  }

  /// Get expected feature ranges (for validation)
  /// These are approximate ranges based on typical Philippine geography
  Map<String, Map<String, dynamic>> getExpectedFeatureRanges() {
    return {
      'elevation': {'min': -10.0, 'max': 3000.0, 'unit': 'meters'},
      'slope': {'min': 0.0, 'max': 90.0, 'unit': 'degrees'},
      'flow_accumulation': {'min': 0.0, 'max': 1000000.0, 'unit': 'cells'},
      'dist_to_road': {'min': 0.0, 'max': 50000.0, 'unit': 'meters'},
      'population': {'min': 0.0, 'max': 50000.0, 'unit': 'people per km²'},
      'dist_to_landslide': {'min': 0.0, 'max': 500000.0, 'unit': 'meters'},
    };
  }
}
