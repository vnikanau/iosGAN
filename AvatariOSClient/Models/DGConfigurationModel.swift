//
//  DGConfigurationModel.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 8/24/20.
//

import UIKit

struct DGMainConfigurationModel: Codable {
    var derive_output_name: Bool = false
    var depth_scaling: UInt = 1000
    var reconstruction_mode: Bool = false
    var poisson_depth: UInt = 9
    var final_ba_iterations: UInt = 0
    var remove_background: UInt = 1 // 1 by default for iPad/iPhone
    var poisson_depth_min: UInt =  5
    var target_triangles_count: UInt = 150000
    var downsample_model_points: UInt = 0
    var poisson_enable_linear_fit: Bool = false
    var reconstruction_sparse_surfel_cell_size: UInt = 1
    var gui_run: Bool = false
    var mesh_reconstruction_method: String = "poisson"
    var enable_smoothing: Bool = false
    var send_amqpinfo: Bool = false
    var send_caminfo: Bool = false
    var send_pointcloud: Bool = false
    var send_pointcloudC: Bool = false
    var send_pointcloudCN: Bool = false
    var auto_upload: Bool = true
//    var async_frames: Bool = false // Sync / Asycn mode. Depths and frames may go separately
//    var dummy_mode: Bool = false // Dump frameset mode. If set to true dataset would be dump
}

struct DGBadSlamConfigurationModel: Codable {
    var max_surfel_count: UInt  = 15000000
    var sparse_surfel_cell_size: UInt = 1
    var keyframe_interval: UInt = 4 // 
    var use_photometric_residuals: Bool = false //true // true for color frames
    var fps_restriction: UInt = 0
    var max_depth: Float = 5
    var median_filter_and_densify_iterations: UInt = 1
    var use_motion_model: Bool = true
    var min_observation_count: UInt = 4 // Каждая точка должна повториться n кол-во раз иначе отсекается
    var num_scales: UInt = 4
    var max_num_ba_iterations_per_keyframe: UInt = 50
}

struct DGPathConfigurationModel: Codable {
    var result_folder_path: String? = nil
    var dataset_folder_path: String = "live://amqp"
}

struct DGConfigurationModel: Codable {
    var MainConfig: DGMainConfigurationModel
    var BadSlamConfig: DGBadSlamConfigurationModel
    var PathConfig:DGPathConfigurationModel

    init() {
        MainConfig = DGMainConfigurationModel()
        BadSlamConfig = DGBadSlamConfigurationModel()
        PathConfig = DGPathConfigurationModel()
    }
}
