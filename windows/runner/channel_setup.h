#ifndef RUNNER_CHANNEL_SETUP_H_
#define RUNNER_CHANNEL_SETUP_H_

// =============================================================================
// channel_setup.h — Tutorial course: Windows channel declarations
//
// Call SetupChannels() once after the FlutterViewController is created,
// passing its binary messenger.  All channels are stored as member variables
// of ChannelManager so their lifetimes match the window.
// =============================================================================

#include <flutter/basic_message_channel.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <thread>

// Alias for the EncodableValue variant used throughout Windows channel code.
using EncodableVal  = flutter::EncodableValue;
using EncodableMap  = flutter::EncodableMap;
using EncodableList = flutter::EncodableList;

class ChannelManager {
 public:
  explicit ChannelManager(flutter::BinaryMessenger* messenger);
  ~ChannelManager();

  // Non-copyable / non-movable — channels hold raw pointers.
  ChannelManager(const ChannelManager&) = delete;
  ChannelManager& operator=(const ChannelManager&) = delete;

 private:
  // ── Lesson 01: MethodChannel ────────────────────────────────────────────────
  void SetupMethodChannel(flutter::BinaryMessenger* messenger);

  // ── Lesson 02: EventChannel ─────────────────────────────────────────────────
  void SetupBatteryEventChannel(flutter::BinaryMessenger* messenger);

  // ── Lesson 03: BasicMessageChannel ─────────────────────────────────────────
  // NOTE: Windows only ships StandardMessageCodec and StandardMethodCodec.
  // StringCodec and JsonMessageCodec are not available on Windows.
  // This channel uses StandardMessageCodec on both the Dart and C++ sides.
  void SetupMessageChannel(flutter::BinaryMessenger* messenger);

  // ── Owned channel objects ────────────────────────────────────────────────────
  std::unique_ptr<flutter::MethodChannel<EncodableVal>>       method_channel_;
  std::unique_ptr<flutter::EventChannel<EncodableVal>>        battery_channel_;
  std::unique_ptr<flutter::BasicMessageChannel<EncodableVal>> message_channel_;

  // Background thread + stop flag for the battery EventChannel demo.
  std::thread  battery_thread_;
  bool         battery_stop_ = false;
};

// Free function called from FlutterWindow::OnCreate().
// Returns a heap-allocated ChannelManager; the caller owns it.
std::unique_ptr<ChannelManager> SetupChannels(
    flutter::BinaryMessenger* messenger);

#endif  // RUNNER_CHANNEL_SETUP_H_
