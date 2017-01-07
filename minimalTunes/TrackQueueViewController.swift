//
//  TrackQueueViewController.swift
//  minimalTunes
//
//  Created by John Moody on 12/1/16.
//  Copyright © 2016 John Moody. All rights reserved.
//

import Cocoa

enum TrackQueueViewType {
    case pastTrack
    case currentTrack
    case futureTrack
    case source
}

class TrackQueueView: NSObject {
    
    var track: Track?
    var source: String?
    var viewType: TrackQueueViewType?
    var wasQueuedManually: Bool?
    
}

class TrackNameTableCell: NSTableCellView {}

class NowPlayingCell: NSTableCellView {}

class FutureTrackCell: NSTableCellView {}

class PastTrackCell: NSTableCellView {}

class FromSourceDividerCell: NSTableCellView {}

class FromSourceCell: NSTableCellView {}

class TrackQueueViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    var trackQueue: [TrackQueueView] = [TrackQueueView]()
    var mainWindowController: MainWindowController?
    
    @IBOutlet weak var tableView: TableViewYouCanPressSpacebarOn!
    
    var dragTypes = ["Track", "public.TrackQueueView"]
    
    var currentContext: String?
    var currentTrackIndex: Int?
    var numPastTracks = 0
    var numPastTracksToShow = 3
    var globalOffset = 0
    var showAllTracks = false
    
    func reloadData() {
        tableView?.reloadData()
    }
    
    func toggleHidden(state: Int) {
        switch state {
        case NSOnState:
            tableView?.hidden = false
        default:
            tableView?.hidden = true
        }
    }
    
    func tableView(tableView: NSTableView, writeRowsWithIndexes rowIndexes: NSIndexSet, toPasteboard pboard: NSPasteboard) -> Bool {
        print(rowIndexes)
        print(tableView.numberOfRows)
        if rowIndexes.containsIndex(tableView.numberOfRows - 1) {
            print("not writing rows")
            return false
        }
        else {
            print("writing rows")
            let coded = NSKeyedArchiver.archivedDataWithRootObject(rowIndexes)
            pboard.setData(coded, forType: "public.TrackQueueView")
            return true
        }
    }
    
    func tableView(tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAtPoint screenPoint: NSPoint, forRowIndexes rowIndexes: NSIndexSet) {
        print("dragging session will begin called")
    }
    
    func changeCurrentTrack(track: Track, context: String) {
        print("change current track called")
        if (trackQueue.count == 0) {
            let newCurrentTrackView = TrackQueueView()
            newCurrentTrackView.viewType = .currentTrack
            newCurrentTrackView.track = track
            trackQueue.append(newCurrentTrackView)
            let newSourceView = TrackQueueView()
            newSourceView.source = context
            newSourceView.viewType = .source
            trackQueue.append(newSourceView)
            currentTrackIndex = 0
        }
        else {
            if currentTrackIndex != nil {
                insertTrackInQueue(track, index: currentTrackIndex! + 1, context: context, manually: false)
                /*let newCurrentTrackView = TrackQueueView()
                newCurrentTrackView.viewType = .futureTrack
                newCurrentTrackView.track = track
                trackQueue.insert(newCurrentTrackView, atIndex: currentTrackIndex! + 1)*/
            } else {
                currentTrackIndex = 0
                (trackQueue[currentTrackIndex!]).viewType = .currentTrack
            }
        }
        tableView?.reloadData()
    }
    
    func addTrackToQueue(track: Track, context: String, tense: Int, manually: Bool) {
        let newFutureTrackView = TrackQueueView()
        if (tense == 0) {
            newFutureTrackView.viewType = .currentTrack
        }
        else {
            newFutureTrackView.viewType = .futureTrack
        }
        newFutureTrackView.track = track
        if manually == true {
            newFutureTrackView.wasQueuedManually = true
        }
        if trackQueue.count > 0 {
            trackQueue.removeLast()
        }
        trackQueue.append(newFutureTrackView)
        let newSourceView = TrackQueueView()
        newSourceView.source = context
        newSourceView.viewType = .source
        trackQueue.append(newSourceView)
    }
    
    @IBAction func togglePastTracks(sender: AnyObject) {
        if showAllTracks == true {
            showAllTracks = false
        }
        else if showAllTracks == false {
            showAllTracks = true
        }
        tableView?.reloadData()
    }
    @IBAction func makePlaylistFromTrackQueueSelection(sender: AnyObject) {
        makePlaylistFromSelection()
    }
    
    func insertTrackInQueue(track: Track, index: Int, context: String, manually: Bool) {
        if index < trackQueue.count {
            let newTrackView = TrackQueueView()
            newTrackView.track = track
            newTrackView.source = context
            newTrackView.viewType = .futureTrack
            if manually == true {
                newTrackView.wasQueuedManually = true
            }
            trackQueue.insert(newTrackView, atIndex: index)
        }
        else {
            addTrackToQueue(track, context: context, tense: 1, manually: manually)
        }
        tableView?.reloadData()
    }
    
    func nextTrack() {
        print("next track in track queue called")
        if currentTrackIndex != nil && trackQueue.count > 0 && (trackQueue[currentTrackIndex! + 1]).viewType == .futureTrack {
            (trackQueue[currentTrackIndex!]).viewType = .pastTrack
            currentTrackIndex! += 1
            numPastTracks += 1
            if numPastTracks >= numPastTracksToShow {
                globalOffset += 1
            }
            if (trackQueue.count > currentTrackIndex! + 1) {
                print("detected queued tracks")
                trackQueue[currentTrackIndex!].viewType = .currentTrack
            }
        } else {
            if trackQueue.count > 0 {
                currentTrackIndex = 0
                trackQueue[currentTrackIndex!].viewType = .currentTrack
            }
        }
        tableView?.reloadData()
    }
    
    func uninitializeTrackQueue() {
        trackQueue.removeAtIndex(0)
        currentTrackIndex = nil
    }
    
    func skipToPreviousTrack() {
        print("skip to previous track called")
        //currently micromanages the MWC queue and the audio module, in spite of better judgement
        if currentTrackIndex != nil {
            if trackQueue[currentTrackIndex!].wasQueuedManually != true {
                trackQueue.removeAtIndex(currentTrackIndex!)
                if trackQueue.count > 1 {
                    if currentTrackIndex! != 0 {
                        let track = trackQueue[currentTrackIndex! - 1]
                        trackQueue[currentTrackIndex! - 1].viewType = .currentTrack
                        currentTrackIndex! -= 1
                        numPastTracks -= 1
                        if numPastTracks >= numPastTracksToShow - 1 {
                            globalOffset -= 1
                        }
                        mainWindowController?.delegate?.audioModule.currentTrackLocation = track.track?.location
                        mainWindowController?.delegate?.audioModule.skip_backward()
                        mainWindowController?.current_source_index! -= 1
                        mainWindowController?.currentTrack?.is_playing = false
                        mainWindowController?.currentTableViewController?.reloadNowPlayingForTrack(mainWindowController!.currentTrack!)
                        mainWindowController?.currentTrack = track.track
                        mainWindowController?.timer?.invalidate()
                        mainWindowController?.initializeInterfaceForNewTrack()
                        mainWindowController?.currentTrack?.is_playing = true
                        mainWindowController?.currentTableViewController?.reloadNowPlayingForTrack(mainWindowController!.currentTrack!)
                    } else {
                        mainWindowController?.currentTrack?.is_playing = false
                        mainWindowController?.currentTableViewController?.reloadNowPlayingForTrack(mainWindowController!.currentTrack!)
                        mainWindowController?.currentTrack = nil
                        mainWindowController?.delegate?.audioModule.currentTrackLocation = nil
                        mainWindowController?.delegate?.audioModule.skip_backward()
                        currentTrackIndex = nil
                    }
                } else {
                    uninitializeTrackQueue()
                    mainWindowController?.currentTrack?.is_playing = false
                    mainWindowController?.currentTableViewController?.reloadNowPlayingForTrack(mainWindowController!.currentTrack!)
                    mainWindowController?.currentTrack = nil
                    mainWindowController?.delegate?.audioModule.currentTrackLocation = nil
                    mainWindowController?.delegate?.audioModule.skip_backward()
                }
            } else {
                if trackQueue.count > 1 {
                    if currentTrackIndex! != 0 {
                        trackQueue[currentTrackIndex!].viewType = .futureTrack
                        let track = trackQueue[currentTrackIndex! - 1]
                        let newFutureTrack = trackQueue[currentTrackIndex!]
                        newFutureTrack.viewType = .futureTrack
                        trackQueue[currentTrackIndex! - 1].viewType = .currentTrack
                        currentTrackIndex! -= 1
                        numPastTracks -= 1
                        if numPastTracks >= numPastTracksToShow - 1 {
                            globalOffset -= 1
                        }
                        mainWindowController?.delegate?.audioModule.currentTrackLocation = track.track?.location
                        mainWindowController?.delegate?.audioModule.skip_backward()
                        mainWindowController?.currentTrack?.is_playing = false
                        mainWindowController?.currentTableViewController?.reloadNowPlayingForTrack(mainWindowController!.currentTrack!)
                        mainWindowController?.currentTrack = track.track
                        mainWindowController?.timer?.invalidate()
                        mainWindowController?.initializeInterfaceForNewTrack()
                        mainWindowController?.currentTrack?.is_playing = true
                        mainWindowController?.currentTableViewController?.reloadNowPlayingForTrack(mainWindowController!.currentTrack!)
                        mainWindowController?.delegate?.audioModule.trackQueue.insert(newFutureTrack.track!, atIndex: 0)
                        mainWindowController?.trackQueue.insert(newFutureTrack.track!, atIndex: 0)
                    } else {
                        mainWindowController?.currentTrack?.is_playing = false
                        mainWindowController?.currentTableViewController?.reloadNowPlayingForTrack(mainWindowController!.currentTrack!)
                        mainWindowController?.currentTrack = nil
                        mainWindowController?.delegate?.audioModule.currentTrackLocation = nil
                        mainWindowController?.delegate?.audioModule.skip_backward()
                        currentTrackIndex = nil
                    }
                } else {
                    uninitializeTrackQueue()
                    mainWindowController?.currentTrack?.is_playing = false
                    mainWindowController?.currentTableViewController?.reloadNowPlayingForTrack(mainWindowController!.currentTrack!)
                    mainWindowController?.currentTrack = nil
                    mainWindowController?.delegate?.audioModule.currentTrackLocation = nil
                    mainWindowController?.delegate?.audioModule.skip_backward()
                }
            }
        }
        print("current track index is \(currentTrackIndex)")
        tableView.reloadData()
    }
    
    func getLastTrack() -> Track? {
        guard currentTrackIndex != nil && trackQueue.count > 2 else {return nil}
        let row = currentTrackIndex! - 1
        return trackQueue[row].track
    }
    
    func tableView(tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableViewDropOperation) -> NSDragOperation {
        let actualRow: Int
        switch showAllTracks {
        case true:
            actualRow = row
        default:
            actualRow = row + globalOffset
        }
        if actualRow <= currentTrackIndex {
            return NSDragOperation.None
        }
        else {
            return NSDragOperation.Every
        }
    }
    
    func makePlaylistFromSelection() {
        var track_id_list = [Int]()
        let select_offset: Int
        switch showAllTracks {
        case true:
            select_offset = 0
        default:
            select_offset = globalOffset
        }
        tableView?.selectedRowIndexes.enumerateIndexesUsingBlock({(index, stop) -> Void in
            let id = self.trackQueue[index + select_offset].track!.id
            track_id_list.append(Int(id!))
        })
        mainWindowController?.createPlaylistFromTracks(track_id_list)
    }
    
    func addTracksToQueue(row: Int?, context: String?, tracks: [Track]) {
        var actualRow: Int
        let theRow = row == nil ? self.tableView.numberOfRows : row!
        switch showAllTracks {
        case true:
            actualRow = theRow
        default:
            actualRow = theRow + globalOffset
        }
        for track in tracks {
            insertTrackInQueue(track, index: actualRow, context: context!, manually: true)
            let queueIndex = currentTrackIndex == nil ? actualRow : actualRow - currentTrackIndex! - 1
            print("queue index \(queueIndex), actualRow \(actualRow), currentIndex \(currentTrackIndex)")
            mainWindowController?.delegate?.audioModule.addTrackToQueue(track, index: queueIndex)
            if queueIndex >= mainWindowController?.trackQueue.count || queueIndex == -1 {
                print("putting \(track.name) at index \(mainWindowController!.trackQueue.count - 1)")
                mainWindowController?.trackQueue.append(track)
            } else {
                print("putting \(track.name) at index \(queueIndex)")
                mainWindowController?.trackQueue.insert(track, atIndex: queueIndex)
            }
            actualRow += 1
        }
        mainWindowController?.makePlayOrderChangesIfNecessaryForQueuedTracks(tracks)
        tableView.reloadData()
    }
    
    func tableView(tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableViewDropOperation) -> Bool {
        var actualRow: Int
        switch showAllTracks {
        case true:
            actualRow = row
        default:
            actualRow = row + globalOffset
        }
        print("accept drop")
        if (info.draggingPasteboard().types!.contains("Track")) {
            let thing = info.draggingPasteboard().dataForType("Track")
            let context = info.draggingPasteboard().stringForType("context")
            let unCodedThing = NSKeyedUnarchiver.unarchiveObjectWithData(thing!) as! NSMutableArray
            let tracks = { () -> [Track] in
                var result = [Track]()
                for trackURI in unCodedThing {
                    let id = managedContext.persistentStoreCoordinator?.managedObjectIDForURIRepresentation(trackURI as! NSURL)
                    result.append(managedContext.objectWithID(id!) as! Track)
                }
                return result
            }()
            addTracksToQueue(row, context: context, tracks: tracks)
        }
        if (info.draggingPasteboard().types!.contains("public.TrackQueueView")) {
            let codedViews = info.draggingPasteboard().dataForType("public.TrackQueueView")
            let rows = NSKeyedUnarchiver.unarchiveObjectWithData(codedViews!) as! NSIndexSet
            var row_offset = 0
            rows.enumerateIndexesUsingBlock({(index, stop) -> Void in
                tableView.moveRowAtIndex(index, toIndex: row + row_offset)
                print(index)
                print(row)
                let actualIndex: Int
                switch self.showAllTracks {
                case true:
                    actualIndex = index
                default:
                    actualIndex = index + self.globalOffset
                }
                swap(&self.trackQueue[actualIndex], &self.trackQueue[actualRow + row_offset])
                self.mainWindowController?.delegate?.audioModule.swapTracks(actualIndex - self.currentTrackIndex! - 1, second_index: actualRow + row_offset - self.currentTrackIndex! - 1)
                swap(&self.mainWindowController!.trackQueue[actualIndex - self.currentTrackIndex! - 1], &self.mainWindowController!.trackQueue[actualRow + row_offset - self.currentTrackIndex! - 1])
                row_offset += 1
            })
        }
        tableView.reloadData()
        return true
    }
    
    
    func updateContext(name: String) {
        if trackQueue.count > 1 {
            trackQueue.removeLast()
        }
        let newSourceView = TrackQueueView()
        newSourceView.source = name
        newSourceView.viewType = .source
        trackQueue.append(newSourceView)
    }
    
    func interpretDeleteEvent() {
        guard tableView.selectedRow > -1 else {return}
        let select_offset: Int
        switch showAllTracks {
        case true:
            select_offset = 0
        default:
            select_offset = globalOffset
        }
        //terrible/slow implementation
        var indices = [Int]()
        for index in tableView.selectedRowIndexes {
            indices.append(index)
        }
        indices.sortInPlace()
        indices = indices.reverse()
        for index in indices {
            print("index is \(index), glos is \(select_offset)")
            self.trackQueue.removeAtIndex(index + select_offset)
            var newIndex: Int = index + select_offset
            if self.currentTrackIndex != nil {
                newIndex -= self.currentTrackIndex!
            }
            print(self.mainWindowController?.trackQueue.removeAtIndex(newIndex - 1))
            self.mainWindowController?.delegate?.audioModule.trackQueue.removeAtIndex(newIndex - 1)
        }
        //print(self.trackQueue)
        //print(self.mainWindowController?.trackQueue)
        tableView.reloadData()
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        switch showAllTracks {
        case true:
            return trackQueue.count
        default:
            return trackQueue.count - globalOffset
        }
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        //uses cell.subviews[x] because IB can't connect outlets from elements to nstablecellview subclasses using .xibs, apparently
        var object: TrackQueueView
        switch showAllTracks {
        case true:
            object = trackQueue[row]
        default:
            object = trackQueue[row + globalOffset]
        }
        if tableColumn?.identifier == "Is Playing" {
            switch object.viewType! {
            case .currentTrack:
                return tableView.makeViewWithIdentifier("nowPlaying", owner: nil) as! NowPlayingCell
            default:
                return nil
            }
        }
        else {
            switch object.viewType! {
            case .pastTrack:
                let result = tableView.makeViewWithIdentifier("pastTrack", owner: nil) as! PastTrackCell
                (result.subviews[2] as! NSTextField).stringValue = object.track!.name!
                var artist_aa_string = ""
                if object.track!.artist != nil {
                    artist_aa_string += object.track!.artist!.name!
                }
                if object.track!.album != nil {
                    artist_aa_string += " - " + object.track!.album!.name!
                }
                (result.subviews[1] as! NSTextField).stringValue = artist_aa_string
                if object.track!.album?.primary_art != nil {
                    let art = object.track?.album?.primary_art
                    let path = art?.artwork_location!
                    let url = NSURL(string: path!)
                    let image = NSImage(contentsOfURL: url!)
                    (result.subviews[0] as! NSImageView).image = image
                }
                else {
                    (result.subviews[0] as! NSImageView).image = nil
                }
                return result
            case .currentTrack:
                let result = tableView.makeViewWithIdentifier("futureTrack", owner: nil) as! TrackNameTableCell
                (result.subviews[2] as! NSTextField).stringValue = object.track!.name!
                var artist_aa_string = ""
                if object.track!.artist != nil {
                    artist_aa_string += object.track!.artist!.name!
                }
                if object.track!.album != nil {
                    artist_aa_string += " - " + object.track!.album!.name!
                }
                (result.subviews[1] as! NSTextField).stringValue = artist_aa_string
                if object.track!.album?.primary_art != nil {
                    let art = object.track?.album?.primary_art
                    let path = art?.artwork_location!
                    let url = NSURL(string: path!)
                    let image = NSImage(contentsOfURL: url!)
                    (result.subviews[0] as! NSImageView).image = image
                }
                else {
                    (result.subviews[0] as! NSImageView).image = nil
                }
                return result
            case .source:
                let result = tableView.makeViewWithIdentifier("source", owner: nil) as! FromSourceCell
                (result.subviews[1] as! NSTextField).stringValue = object.source!
                return result
            case .futureTrack:
                let result = tableView.makeViewWithIdentifier("futureTrack", owner: nil) as! TrackNameTableCell
                (result.subviews[2] as! NSTextField).stringValue = object.track!.name!
                var artist_aa_string = ""
                if object.track!.artist != nil {
                    artist_aa_string += object.track!.artist!.name!
                }
                if object.track!.album != nil {
                    artist_aa_string += " - " + object.track!.album!.name!
                }
                (result.subviews[1] as! NSTextField).stringValue = artist_aa_string
                if object.track!.album?.primary_art != nil {
                    let art = object.track?.album?.primary_art
                    let path = art?.artwork_location!
                    let url = NSURL(string: path!)
                    let image = NSImage(contentsOfURL: url!)
                    (result.subviews[0] as! NSImageView).image = image
                }
                else {
                    (result.subviews[0] as! NSImageView).image = nil
                }
                return result
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView!.setDataSource(self)
        tableView!.setDelegate(self)
        tableView!.registerForDraggedTypes(["Track", "public.TrackQueueView"])
        tableView.trackQueueViewController = self
        // Do view setup here.
    }

    
}
