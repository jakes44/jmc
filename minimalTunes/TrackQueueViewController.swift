//
//  TrackQueueViewController.swift
//  minimalTunes
//
//  Created by John Moody on 12/1/16.
//  Copyright © 2016 John Moody. All rights reserved.
//

import Cocoa
import MultipeerConnectivity

enum TrackQueueViewType {
    case pastTrack
    case currentTrack
    case futureTrack
    case transient
    case source
}

class PlaylistOrderObject: Equatable, Hashable {
    
    var inorder_play_order: [Int]
    var shuffled_play_order: [Int]?
    var current_play_order: [Int]?
    
    init(inorder_play_order: [Int]) {
        self.inorder_play_order = inorder_play_order
    }
    
    var hashValue: Int {
        get {
            return inorder_play_order.count
        }
    }
}

func ==(lpoo: PlaylistOrderObject, rpoo: PlaylistOrderObject) -> Bool {
    return lpoo.inorder_play_order == rpoo.inorder_play_order
}

class TrackQueueView: NSObject {
    
    var track: Track?
    var source: String?
    var sourcePlaylistOrder: PlaylistOrderObject?
    var index: Int?
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
    var temporaryPooForDragging: PlaylistOrderObject?
    var temporaryPooIndexForDragging: Int?
    var currentAudioSource: SourceListItem?
    var currentSourceListItem: SourceListItem?
    var currentSourcePlayOrder: PlaylistOrderObject?
    var currentSourceIndex: Int?
    var currentTrack: Track?
    var shuffle: Bool = false
    
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
    
    func changeCurrentTrack(track: Track) {
        print("change current track called")
        if (trackQueue.count == 0) {
            let newCurrentTrackView = TrackQueueView()
            newCurrentTrackView.viewType = .currentTrack
            newCurrentTrackView.track = track
            newCurrentTrackView.wasQueuedManually = true
            newCurrentTrackView.sourcePlaylistOrder = currentSourcePlayOrder
            trackQueue.append(newCurrentTrackView)
            let newSourceView = TrackQueueView()
            newSourceView.source = currentSourceListItem?.name
            newSourceView.viewType = .source
            trackQueue.append(newSourceView)
            currentTrackIndex = 0
        }
        else {
            if currentTrackIndex != nil {
                insertTrackInQueue(track, index: currentTrackIndex! + 1, context: currentSourceListItem!.name!, manually: false)
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
        if currentSourceListItem != currentAudioSource && manually == true {
            createPlayOrderArray(track, row: nil)
        }
        newFutureTrackView.sourcePlaylistOrder = currentSourcePlayOrder
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
            newTrackView.sourcePlaylistOrder = currentSourcePlayOrder
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
        if currentTrackIndex != nil && trackQueue.count > 0 && ((trackQueue[currentTrackIndex! + 1]).viewType == .futureTrack || trackQueue[currentTrackIndex! + 1].viewType == .transient) {
            (trackQueue[currentTrackIndex!]).viewType = .pastTrack
            currentTrackIndex! += 1
            numPastTracks += 1
            if numPastTracks >= numPastTracksToShow {
                globalOffset += 1
            }
            if (trackQueue.count > currentTrackIndex! + 1) {
                print("detected queued tracks")
                trackQueue[currentTrackIndex!].viewType = .currentTrack
                self.currentTrack = trackQueue[currentTrackIndex!].track
            }
        } else {
            if trackQueue.count > 0 {
                currentTrackIndex = 0
                trackQueue[currentTrackIndex!].viewType = .currentTrack
                self.currentTrack = trackQueue[currentTrackIndex!].track
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
            if trackQueue.count > 1 {
                if currentTrackIndex! != 0 {
                    print("making tqv transient")
                    trackQueue[currentTrackIndex!].viewType = .transient
                    let track = trackQueue[currentTrackIndex! - 1]
                    self.currentTrack = track.track
                    let newFutureTrack = trackQueue[currentTrackIndex!]
                    newFutureTrack.viewType = .transient
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
        print("current track index is \(currentTrackIndex)")
        tableView.reloadData()
    }
    
    func getLastTrack() -> Track? {
        guard currentTrackIndex != nil && trackQueue.count > 2 else {return nil}
        let row = currentTrackIndex! - 1
        return trackQueue[row].track
    }
    
    func getNextTrack() -> Track? {
        if trackQueue.count >= currentTrackIndex! + 3 {
            //addTrackToQueue(trackQueue[currentTrackIndex! + 1].track!, context: self.currentAudioSource!.name!, tense: 2, manually: false)
            return trackQueue[currentTrackIndex! + 1].track
        } else {
            if currentSourcePlayOrder!.current_play_order!.count <= currentSourceIndex! + 1 {
                return nil
            } else {
                var id: Int?
                id = currentSourcePlayOrder!.current_play_order![currentSourceIndex! + 1]
                currentSourceIndex! += 1
                var next_track: Track?
                if currentAudioSource?.is_network == true {
                    next_track = getNetworkTrackWithID(id!)
                } else {
                    next_track = getTrackWithID(id!)
                }
                addTrackToQueue(next_track!, context: self.currentAudioSource!.name!, tense: 2, manually: false)
                return next_track
            }
        }
    }
    
    func modifyPlayOrderArrayForQueuedTracks(tracks: [Track]) {
        for track in tracks {
            if track.id != currentSourcePlayOrder?.current_play_order![currentSourceIndex!] {
                self.currentSourcePlayOrder?.current_play_order = self.currentSourcePlayOrder?.current_play_order?.filter({$0 != track.id})
            }
        }
    }
    
    func makePlayOrderChangesIfNecessaryForQueuedTracks(tracks: [Track]) {
        if currentSourceListItem != currentAudioSource {
            createPlayOrderArray(tracks.last!, row: nil)
        } else {
            modifyPlayOrderArrayForQueuedTracks(tracks)
        }
    }
    
    func modifyPlayOrderForSortDescriptorChange() {
        if currentAudioSource == currentSourceListItem && self.shuffle == false && self.currentTrack != nil {
            let upcomingIDsResult = mainWindowController!.currentTableViewController?.modifyPlayOrderForSortDescriptors(currentSourcePlayOrder!, trackID: Int(self.currentTrack!.id!))
            self.currentSourceIndex = upcomingIDsResult
        }
    }
    
    func createPlayOrderArray(track: Track, row: Int?) {
        print("initialize array called")
        let playOrderArray = mainWindowController!.createPlayOrderForTrackID(Int(track.id!), row: row)
        self.currentAudioSource = currentSourceListItem
        self.currentSourcePlayOrder = playOrderArray.0
        self.currentSourceIndex = playOrderArray.1
        destroyTransientTracks()
    }
    
    func shufflePressed(state: Int) {
        if (state == NSOnState) {
            self.shuffle = true
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: DEFAULTS_SHUFFLE_STRING)
            if currentSourcePlayOrder != nil {
                print("shuffling")
                if currentSourcePlayOrder?.shuffled_play_order != nil {
                    let idArray = currentSourcePlayOrder?.shuffled_play_order
                    var shuffled_array = idArray
                    shuffle_array(&shuffled_array!)
                    if self.currentTrack != nil {
                        if let indexOfPlayedTrack = shuffled_array?.indexOf(Int(self.currentTrack!.id!)) {
                            if indexOfPlayedTrack != 0 {
                                swap(&shuffled_array![shuffled_array!.indexOf(Int(self.currentTrack!.id!))!], &shuffled_array![0])
                            }
                        }
                    }
                    currentSourcePlayOrder?.shuffled_play_order = shuffled_array
                } else {
                    let idArray = currentSourcePlayOrder?.inorder_play_order
                    var shuffled_array = idArray
                    shuffle_array(&shuffled_array!)
                    if self.currentTrack != nil {
                        if let indexOfPlayedTrack = shuffled_array?.indexOf(Int(self.currentTrack!.id!)) {
                            if indexOfPlayedTrack != 0 {
                                swap(&shuffled_array![shuffled_array!.indexOf(Int(self.currentTrack!.id!))!], &shuffled_array![0])
                            }
                        }
                    }
                    currentSourcePlayOrder?.shuffled_play_order = shuffled_array
                }
                currentSourceIndex = 0
                currentSourcePlayOrder?.current_play_order = currentSourcePlayOrder?.shuffled_play_order
            }
        }
        else {
            self.shuffle = false
            NSUserDefaults.standardUserDefaults().setBool(false, forKey: "shuffle")
            if currentSourcePlayOrder != nil {
                currentSourcePlayOrder?.current_play_order = currentSourcePlayOrder!.inorder_play_order
                if self.currentTrack != nil {
                    if let index = currentSourcePlayOrder!.current_play_order!.indexOf(Int(self.currentTrack!.id!)) {
                        self.currentSourceIndex = index
                    }
                } else {
                    self.currentSourceIndex = 0
                }
                print("current source index \(currentSourceIndex)")
            }
        }
        destroyTransientTracks()
    }
    
    func destroyTransientTracks() {
        let transientTQVs = trackQueue.filter({return $0.viewType == .transient})
        for transientTQV in transientTQVs {
            mainWindowController?.delegate?.audioModule.trackQueue.removeFirst()
            trackQueue.removeAtIndex(trackQueue.indexOf(transientTQV)!)
        }
        tableView.reloadData()
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
    
    func addTracksToQueue(row: Int?, tracks: [Track]) {
        var actualRow: Int
        let theRow = row == nil ? self.tableView.numberOfRows : row!
        switch showAllTracks {
        case true:
            actualRow = theRow
        default:
            actualRow = theRow + globalOffset
        }
        for track in tracks {
            insertTrackInQueue(track, index: actualRow, context: currentSourceListItem!.name!, manually: true)
            let queueIndex = currentTrackIndex == nil ? actualRow : actualRow - currentTrackIndex! - 1
            print("queue index \(queueIndex), actualRow \(actualRow), currentIndex \(currentTrackIndex)")
            mainWindowController?.delegate?.audioModule.addTrackToQueue(track, index: queueIndex)
            actualRow += 1
        }
        modifyPlayOrderArrayForQueuedTracks(tracks)
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
            self.temporaryPooForDragging = nil
            self.temporaryPooIndexForDragging = nil
            let unCodedThing = NSKeyedUnarchiver.unarchiveObjectWithData(thing!) as! NSMutableArray
            let tracks = { () -> [Track] in
                var result = [Track]()
                for trackURI in unCodedThing {
                    let id = managedContext.persistentStoreCoordinator?.managedObjectIDForURIRepresentation(trackURI as! NSURL)
                    result.append(managedContext.objectWithID(id!) as! Track)
                }
                return result
            }()
            addTracksToQueue(row, tracks: tracks)
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
            case .transient:
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