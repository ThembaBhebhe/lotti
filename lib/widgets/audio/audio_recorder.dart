import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/audio/vu_meter.dart';

const double iconSize = 64.0;

class AudioRecorderWidget extends StatelessWidget {
  const AudioRecorderWidget({
    Key? key,
    this.linkedId,
  }) : super(key: key);

  final String? linkedId;

  String formatDuration(String str) {
    return str.substring(0, str.length - 7);
  }

  String formatDecibels(double? decibels) {
    var f = NumberFormat("###.0#", "en_US");
    return (decibels != null) ? '${f.format(decibels)} dB' : '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioRecorderCubit, AudioRecorderState>(
        builder: (context, state) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.mic_rounded),
                iconSize: iconSize,
                tooltip: 'Record',
                color: state.status == AudioRecorderStatus.recording
                    ? AppColors.activeAudioControl
                    : AppColors.inactiveAudioControl,
                onPressed: () => context
                    .read<AudioRecorderCubit>()
                    .record(linkedId: linkedId),
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                iconSize: iconSize,
                tooltip: 'Stop',
                color: AppColors.inactiveAudioControl,
                onPressed: () {
                  context.read<AudioRecorderCubit>().stop();
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  formatDuration(state.progress.toString()),
                  style: TextStyle(
                    fontFamily: 'ShareTechMono',
                    fontSize: 32.0,
                    color: AppColors.inactiveAudioControl,
                  ),
                ),
              ),
            ],
          ),
          const VuMeterWidget(height: 16, width: 280),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              formatDecibels(state.decibels),
              style: TextStyle(
                fontFamily: 'ShareTechMono',
                fontSize: 20.0,
                color: AppColors.inactiveAudioControl,
              ),
            ),
          ),
        ],
      );
    });
  }
}
