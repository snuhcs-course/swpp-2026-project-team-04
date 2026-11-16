"""Regression checks for knee model selection and portable inference."""
import tempfile
import unittest
from pathlib import Path

import numpy as np

from infer_pushup_knee import ExportedKneeModel
from train_pushup_knee_native import counts, fit, operating_points, predict
from train_pushup_knee_specialist import choose_threshold


class KneeStudyTest(unittest.TestCase):
    def test_threshold_respects_normal_loss_and_strict_boundary(self):
        labels = np.array([0, 0, 0, 1, 1])
        probability = np.array([.1, .2, .7, .6, .9])
        threshold, loss, recall = choose_threshold(labels, probability, 0)
        self.assertEqual(threshold, .7)
        self.assertEqual(loss, 0)
        self.assertEqual(recall, .5)

    def test_veto_counts_only_new_rejections_and_never_promotes_invalid(self):
        result = counts(np.array([0, 0, 1, 1]),
                        np.array([True, False, True, False]),
                        np.array([.1, .1, .9, .9]), .5)
        self.assertEqual(result['final_normal'], 1)
        self.assertEqual(result['final_knee_normal'], 0)
        self.assertEqual(result['recovered_knee'], 1)
        self.assertEqual(result['extra_normal_loss'], 0)

    def test_operating_point_enforces_each_domain_normal_budget(self):
        labels = np.array([0, 0, 1, 1])
        original = np.ones(4, dtype=bool)
        points = operating_points(labels, original, np.array([.1, .2, .6, .9]),
                                  labels, original, np.array([.1, .8, .7, .95]))
        for point in points:
            for domain in ['web', 'native']:
                count = point[domain]
                self.assertLessEqual(count['extra_normal_loss'] / count['original_normal'],
                                     point['cap'])

    def test_exported_logistic_matches_training_predictor(self):
        rng = np.random.default_rng(41)
        features = rng.normal(size=(50, 8)).astype(np.float32)
        labels = (features[:, 0] > 0).astype(int)
        fitted = fit(features, labels, np.zeros(50, dtype=bool),
                     dict(C=.1, native_weight=1))
        scaler, model = fitted
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'model.npz'
            np.savez(path, mean=scaler.mean_, scale=scaler.scale_,
                     weights=model.coef_[0], bias=model.intercept_[0], threshold=.6)
            exported = ExportedKneeModel(path)
            np.testing.assert_allclose(exported.probability(features), predict(fitted, features),
                                       rtol=1e-12, atol=1e-12)
            np.testing.assert_array_equal(exported.reject(features), predict(fitted, features) > .6)
            with self.assertRaises(ValueError):
                exported.probability(np.zeros((2, 7)))

    def test_exported_neural_network_and_tree_match_training(self):
        rng = np.random.default_rng(42)
        features = rng.normal(size=(80, 8)).astype(np.float32)
        labels = (features[:, 0] * features[:, 1] > 0).astype(int)
        configurations = [dict(kind='mlp', native_weight=1),
                          dict(kind='tree', depth=3, native_weight=1)]
        for config in configurations:
            with self.subTest(kind=config['kind']):
                fitted = fit(features, labels, np.zeros(80, dtype=bool), config)
                scaler, model = fitted
                arrays = dict(mean=scaler.mean_, scale=scaler.scale_, threshold=.8,
                              kind=config['kind'])
                if config['kind'] == 'mlp':
                    arrays['layers'] = len(model.coefs_)
                    for i, (weights, bias) in enumerate(zip(model.coefs_, model.intercepts_)):
                        arrays[f'weights_{i}'] = weights
                        arrays[f'bias_{i}'] = bias
                else:
                    tree = model.tree_
                    arrays.update(left=tree.children_left, right=tree.children_right,
                                  feature=tree.feature, split=tree.threshold,
                                  value=tree.value[:, 0, :])
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory) / 'model.npz'
                    np.savez(path, **arrays)
                    exported = ExportedKneeModel(path)
                    np.testing.assert_allclose(exported.probability(features),
                                               predict(fitted, features), atol=1e-6)
                    np.testing.assert_array_equal(exported.reject(features),
                                                  predict(fitted, features) > .8)


if __name__ == '__main__':
    unittest.main()
