import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lotti/widgets/audio/audio_recorder.dart';

class RecordAudioPage extends StatefulWidget {
  const RecordAudioPage({
    Key? key,
    @PathParam() this.linkedId,
  }) : super(key: key);
  final String? linkedId;

  @override
  State<RecordAudioPage> createState() => _RecordAudioPageState();
}

class _RecordAudioPageState extends State<RecordAudioPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AudioRecorderWidget(
            linkedId: widget.linkedId,
          ),
        ],
      ),
    );
  }
}
