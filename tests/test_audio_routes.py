import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('audio_routes',Path(__file__).resolve().parents[1]/'scripts/forynarch-audio.py')
audio=importlib.util.module_from_spec(spec);spec.loader.exec_module(audio)

def node(identity,serial,kind,**props):
    return {'id':identity,'type':'PipeWire:Interface:Node','info':{'props':{'object.serial':serial,'media.class':kind,**props}}}

def graph():
    return [node(10,100,'Audio/Sink',**{'node.name':'speakers'}),node(11,101,'Audio/Source',**{'node.name':'microphone'}),
            node(20,200,'Stream/Output/Audio',**{'application.id':'qa.player','application.name':'QA Player'}),
            node(21,201,'Stream/Input/Audio',**{'application.id':'qa.player','application.name':'QA Player'})]

class AudioRoutes(unittest.TestCase):
    def test_app_playback_and_capture_are_grouped_with_distinct_directions(self):
        data=audio.snapshot(graph())
        self.assertEqual(len(data['apps']),1)
        self.assertEqual(data['apps'][0]['output'][0]['serial'],'200')
        self.assertEqual(data['apps'][0]['input'][0]['serial'],'201')
        self.assertEqual(len(data['devices']['input']),1)

    def test_recycled_ids_disconnected_targets_and_cross_direction_are_rejected(self):
        request={'streams':[{'id':20,'serial':'200'}],'direction':'output','target':'100'}
        for mutation in ({'target':'101'},{'target':'999'},{'streams':[{'id':20,'serial':'999'}]},{'streams':[{'id':True,'serial':'200'}]}):
            with self.subTest(mutation=mutation),patch.object(audio,'command') as run,self.assertRaises(ValueError):
                audio.route({**request,**mutation},graph())
            run.assert_not_called()

    def test_default_and_app_managed_routes_have_separate_behavior(self):
        request={'streams':[{'id':20,'serial':'200'}],'direction':'output','target':'default'}
        with patch.object(audio,'command') as run:
            audio.route(request,graph())
            self.assertIn('0',run.call_args.args[0])
            self.assertNotIn('-d',run.call_args.args[0])
        with patch.object(audio,'command') as run:
            audio.route({**request,'target':'app'},graph())
            self.assertIn('-d',run.call_args.args[0])

    def test_invalid_batch_is_checked_before_moving_any_stream(self):
        with patch.object(audio,'command') as run,self.assertRaises(ValueError):
            audio.route({'streams':[{'id':20,'serial':'200'},{'id':99,'serial':'999'}],'direction':'output','target':'100'},graph())
        run.assert_not_called()

    def test_app_monitor_recording_and_strict_targets_keep_their_constraints(self):
        nodes=graph();nodes[3]['info']['props']['stream.capture.sink']=True
        with self.assertRaises(ValueError):audio.route({'streams':[{'id':21,'serial':'201'}],'direction':'input','target':'101'},nodes)
        nodes=graph();nodes[2]['info']['props']['node.dont-fallback']=True
        with self.assertRaises(ValueError):audio.route({'streams':[{'id':20,'serial':'200'}],'direction':'output','target':'default'},nodes)
